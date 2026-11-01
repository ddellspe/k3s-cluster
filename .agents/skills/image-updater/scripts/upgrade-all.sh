#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# Complete Container Image Upgrade Automation for k3s-cluster
# ==============================================================================
# This script audits upstream container image releases, checks inter-service
# couplings (e.g. Open-WebUI + Playwright, ARC controller + CRDs + runners),
# updates YAML manifests, deploys via kubectl, verifies rollouts and endpoints,
# and commits/pushes changes to Git in a single automated run.
# ==============================================================================

# Text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default flags
DRY_RUN=false
CHECK_ONLY=false
DO_COMMIT=true
DO_PUSH=true
SKIP_HEALTH=false

# Root directory of the repository
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_step()    { echo -e "\n${CYAN}${BOLD}>>> $*${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ------------------------------------------------------------------------------
# CLI Argument Parsing
# ------------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --check               Audit upstream releases only; don't modify files or cluster.
  --dry-run             Audit and show planned manifest changes without applying or committing.
  --no-push             Commit changes locally, but do not push to remote.
  --no-commit           Apply manifests and verify rollouts, but do not create git commit.
  --skip-health-checks  Skip HTTP endpoint probing after rollout.
  -h, --help            Show this help message.

Examples:
  $(basename "$0")                    # Full end-to-end upgrade, apply, test & push
  $(basename "$0") --dry-run          # Preview available updates without making changes
  $(basename "$0") --no-push          # Upgrade and commit locally, verify before push
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_ONLY=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-push)
      DO_PUSH=false
      shift
      ;;
    --no-commit)
      DO_COMMIT=false
      DO_PUSH=false
      shift
      ;;
    --skip-health-checks)
      SKIP_HEALTH=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      ;;
  esac
done

# ------------------------------------------------------------------------------
# Environment & Prerequisite Checks
# ------------------------------------------------------------------------------
ensure_prerequisites() {
  log_info "Verifying prerequisites and cluster connectivity..."

  # Check and auto-add kubectl from Rancher Desktop if missing from PATH
  if ! command -v kubectl >/dev/null 2>&1; then
    if [ -x "/mnt/c/Program Files/Rancher Desktop/resources/resources/linux/bin/kubectl" ]; then
      export PATH="/mnt/c/Program Files/Rancher Desktop/resources/resources/linux/bin:$PATH"
    fi
  fi

  for tool in curl jq git sed kubectl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      log_error "Required tool not found in PATH: $tool"
      exit 1
    fi
  done

  # Verify cluster connectivity
  if ! kubectl get nodes --request-timeout=10s >/dev/null 2>&1; then
    log_error "Cannot connect to Kubernetes cluster via kubectl. Ensure kubeconfig is valid and reachable."
    exit 1
  fi
  log_success "Environment and cluster connectivity verified."
}

# ------------------------------------------------------------------------------
# Upstream Tag Fetchers
# ------------------------------------------------------------------------------
fetch_github_latest() {
  local repo="$1"
  curl -s "https://api.github.com/repos/${repo}/releases?per_page=20" | \
    jq -r '.[].tag_name' 2>/dev/null | grep -E '^v?[0-9]+\.[0-9]+(\.[0-9]+)?$' | sort -V | tail -n 1
}

fetch_github_arc_latest() {
  curl -s "https://api.github.com/repos/actions/actions-runner-controller/releases?per_page=10" | \
    jq -r '.[].tag_name' 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1
}

fetch_openwebui_playwright_req() {
  local tag="$1"
  curl -s "https://raw.githubusercontent.com/open-webui/open-webui/${tag}/pyproject.toml" 2>/dev/null | \
    grep -oE 'playwright==[0-9]+\.[0-9]+\.[0-9]+' | cut -d'=' -f3 || echo ""
}

fetch_dockerhub_alpine_k8s() {
  curl -4 -s --max-time 10 "https://hub.docker.com/v2/repositories/alpine/k8s/tags?page_size=25" | \
    jq -r '.results[].name' 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1
}

# ------------------------------------------------------------------------------
# Audit & Comparison
# ------------------------------------------------------------------------------
ensure_prerequisites

log_step "Auditing container images against upstream releases"

# 1. Open-WebUI & Playwright
CUR_OWUI=$(grep -oE 'image: ghcr.io/open-webui/open-webui:.*' llm/open-webui/deployment.yaml | awk -F: '{print $3}')
LATEST_OWUI=$(fetch_github_latest "open-webui/open-webui")
CUR_PLAYWRIGHT=$(grep -oE 'image: mcr.microsoft.com/playwright/python:.*' llm/playwright/deployment.yaml | awk -F: '{print $3}')
TARGET_PLAYWRIGHT_VER=$(fetch_openwebui_playwright_req "$LATEST_OWUI")
TARGET_PLAYWRIGHT="v${TARGET_PLAYWRIGHT_VER}-noble"

# 2. ARC Controller & Runners
CUR_ARC=$(grep -oE 'image: "ghcr.io/actions/gha-runner-scale-set-controller:.*"' dev-infra/actions-runner/controller/deployment.yaml | tr -d '"' | awk -F: '{print $3}')
LATEST_ARC=$(fetch_github_arc_latest)

# 3. Zot Registry
CUR_ZOT=$(grep -oE 'image: ghcr.io/project-zot/zot:.*' dev-infra/registry/deployment.yaml | awk -F: '{print $3}')
LATEST_ZOT=$(fetch_github_latest "project-zot/zot")

# 4. Grafana
CUR_GRAFANA=$(grep -oE 'image: grafana/grafana:.*' monitoring/grafana/deployment.yaml | awk -F: '{print $3}')
LATEST_GRAFANA=$(fetch_github_latest "grafana/grafana" | sed 's/^v//')

# 5. Prometheus
CUR_PROM=$(grep -oE 'image: prom/prometheus:.*' monitoring/prometheus/deployment.yaml | awk -F: '{print $3}')
LATEST_PROM=$(fetch_github_latest "prometheus/prometheus")

# 6. Prometheus Config Reloader
CUR_RELOADER=$(grep -oE 'image: quay.io/prometheus-operator/prometheus-config-reloader:.*' monitoring/prometheus/deployment.yaml | awk -F: '{print $3}')
LATEST_RELOADER=$(fetch_github_latest "prometheus-operator/prometheus-operator")

# 7. Node Exporter
CUR_NODE_EXP=$(grep -oE 'image: quay.io/prometheus/node-exporter:.*' monitoring/node-exporter/daemonset.yaml | awk -F: '{print $3}')
LATEST_NODE_EXP=$(fetch_github_latest "prometheus/node_exporter")

# 8. Skyhook Radar
CUR_RADAR=$(grep -oE 'image: ghcr.io/skyhook-io/radar:.*' radar/deployment.yaml | awk -F: '{print $3}')
LATEST_RADAR=$(fetch_github_latest "skyhook-io/radar" | sed 's/^v//')

# 9. System Upgrade Controller
CUR_SUC=$(grep -oE 'image: rancher/system-upgrade-controller:.*' system-upgrade/deployment.yaml | awk -F: '{print $3}')
LATEST_SUC=$(fetch_github_latest "rancher/system-upgrade-controller")

# 10. Alpine k8s helper
CUR_ALPINE_K8S=$(grep -oE 'image: alpine/k8s:.*' infra/pod-remediator/deployment.yaml | awk -F: '{print $3}')
LATEST_ALPINE_K8S=$(fetch_dockerhub_alpine_k8s)

# Print Status Table
print_row() {
  local item="$1"
  local cur="$2"
  local lat="$3"
  local note="$4"
  if [ -z "$lat" ]; then
    printf "| %-30s | %-16s | %-16s | ${RED}%-10s${NC} | %-32s |\n" "$item" "$cur" "UNKNOWN" "ERROR" "$note"
  elif [ "$cur" = "$lat" ]; then
    printf "| %-30s | %-16s | %-16s | ${GREEN}%-10s${NC} | %-32s |\n" "$item" "$cur" "$lat" "Up to date" "$note"
  else
    printf "| %-30s | %-16s | %-16s | ${YELLOW}%-10s${NC} | %-32s |\n" "$item" "$cur" "$lat" "UPDATE" "$note"
  fi
}

echo "| Component                      | Current Version  | Latest Version   | Status     | Notes                            |"
echo "|--------------------------------|------------------|------------------|------------|----------------------------------|"
print_row "Open-WebUI" "$CUR_OWUI" "$LATEST_OWUI" "Coupled with Playwright"
print_row "Playwright" "$CUR_PLAYWRIGHT" "$TARGET_PLAYWRIGHT" "Open-WebUI pinned requirement"
print_row "ARC ScaleSet Controller" "$CUR_ARC" "$LATEST_ARC" "Requires CRD server-side sync"
print_row "Zot OCI Registry" "$CUR_ZOT" "$LATEST_ZOT" "Registry deployment"
print_row "Grafana" "$CUR_GRAFANA" "$LATEST_GRAFANA" "Monitoring dashboard"
print_row "Prometheus" "$CUR_PROM" "$LATEST_PROM" "Prometheus server"
print_row "Prometheus Config Reloader" "$CUR_RELOADER" "$LATEST_RELOADER" "Prometheus sidecar"
print_row "Node Exporter" "$CUR_NODE_EXP" "$LATEST_NODE_EXP" "Node metrics daemonset"
print_row "Skyhook Radar" "$CUR_RADAR" "$LATEST_RADAR" "Cluster topology & issues"
print_row "System Upgrade Controller" "$CUR_SUC" "$LATEST_SUC" "Node OS/k3s upgrades"
print_row "Alpine k8s helper" "$CUR_ALPINE_K8S" "$LATEST_ALPINE_K8S" "Remediator & upgrade cronjob"
echo ""

# Exit early if check only
if [ "$CHECK_ONLY" = true ]; then
  exit 0
fi

# Track updates to execute
UPDATED_COMPONENTS=()
MODIFIED_FILES=()

# ------------------------------------------------------------------------------
# 1. Skyhook Radar Update
# ------------------------------------------------------------------------------
if [ -n "$LATEST_RADAR" ] && [ "$CUR_RADAR" != "$LATEST_RADAR" ]; then
  log_step "Updating Skyhook Radar: $CUR_RADAR -> $LATEST_RADAR"
  if [ "$DRY_RUN" = false ]; then
    sed -i "s|image: ghcr.io/skyhook-io/radar:.*|image: ghcr.io/skyhook-io/radar:${LATEST_RADAR}|" radar/deployment.yaml
    kubectl apply -k radar/
    kubectl rollout status deployment/radar -n radar --timeout=180s
    MODIFIED_FILES+=("radar/deployment.yaml")
  fi
  UPDATED_COMPONENTS+=("radar: $CUR_RADAR -> $LATEST_RADAR")
fi

# ------------------------------------------------------------------------------
# 2. Alpine k8s Helper (Pod Remediator & System Upgrade Auto-Updater)
# ------------------------------------------------------------------------------
if [ -n "$LATEST_ALPINE_K8S" ] && [ "$CUR_ALPINE_K8S" != "$LATEST_ALPINE_K8S" ]; then
  log_step "Updating Alpine k8s helper: $CUR_ALPINE_K8S -> $LATEST_ALPINE_K8S"
  if [ "$DRY_RUN" = false ]; then
    sed -i "s|image: alpine/k8s:.*|image: alpine/k8s:${LATEST_ALPINE_K8S}|" infra/pod-remediator/deployment.yaml
    sed -i "s|image: alpine/k8s:.*|image: alpine/k8s:${LATEST_ALPINE_K8S}|" system-upgrade/cronjob.yaml
    kubectl apply -k infra/pod-remediator/
    kubectl rollout status deployment/pod-remediator -n kube-system --timeout=180s
    kubectl apply -f system-upgrade/cronjob.yaml
    MODIFIED_FILES+=("infra/pod-remediator/deployment.yaml" "system-upgrade/cronjob.yaml")
  fi
  UPDATED_COMPONENTS+=("alpine/k8s (pod-remediator & cronjob): $CUR_ALPINE_K8S -> $LATEST_ALPINE_K8S")
fi

# ------------------------------------------------------------------------------
# 3. Prometheus Config Reloader
# ------------------------------------------------------------------------------
if [ -n "$LATEST_RELOADER" ] && [ "$CUR_RELOADER" != "$LATEST_RELOADER" ]; then
  log_step "Updating Prometheus Config Reloader: $CUR_RELOADER -> $LATEST_RELOADER"
  if [ "$DRY_RUN" = false ]; then
    sed -i "s|image: quay.io/prometheus-operator/prometheus-config-reloader:.*|image: quay.io/prometheus-operator/prometheus-config-reloader:${LATEST_RELOADER}|" monitoring/prometheus/deployment.yaml
    kubectl apply -k monitoring/prometheus/
    kubectl rollout status deployment/prometheus -n monitoring --timeout=180s
    MODIFIED_FILES+=("monitoring/prometheus/deployment.yaml")
  fi
  UPDATED_COMPONENTS+=("prometheus-config-reloader: $CUR_RELOADER -> $LATEST_RELOADER")
fi

# ------------------------------------------------------------------------------
# 4. Prometheus Server
# ------------------------------------------------------------------------------
if [ -n "$LATEST_PROM" ] && [ "$CUR_PROM" != "$LATEST_PROM" ]; then
  log_step "Updating Prometheus: $CUR_PROM -> $LATEST_PROM"
  if [ "$DRY_RUN" = false ]; then
    sed -i "s|image: prom/prometheus:.*|image: prom/prometheus:${LATEST_PROM}|" monitoring/prometheus/deployment.yaml
    kubectl apply -k monitoring/prometheus/
    kubectl rollout status deployment/prometheus -n monitoring --timeout=180s
    MODIFIED_FILES+=("monitoring/prometheus/deployment.yaml")
  fi
  UPDATED_COMPONENTS+=("prometheus: $CUR_PROM -> $LATEST_PROM")
fi

# ------------------------------------------------------------------------------
# 5. Grafana
# ------------------------------------------------------------------------------
if [ -n "$LATEST_GRAFANA" ] && [ "$CUR_GRAFANA" != "$LATEST_GRAFANA" ]; then
  log_step "Updating Grafana: $CUR_GRAFANA -> $LATEST_GRAFANA"
  if [ "$DRY_RUN" = false ]; then
    sed -i "s|image: grafana/grafana:.*|image: grafana/grafana:${LATEST_GRAFANA}|" monitoring/grafana/deployment.yaml
    kubectl apply -k monitoring/grafana/
    kubectl rollout status deployment/grafana -n monitoring --timeout=180s
    MODIFIED_FILES+=("monitoring/grafana/deployment.yaml")
  fi
  UPDATED_COMPONENTS+=("grafana: $CUR_GRAFANA -> $LATEST_GRAFANA")
fi

# ------------------------------------------------------------------------------
# 6. Actions Runner Controller (ARC), CRDs & Runner ScaleSets
# ------------------------------------------------------------------------------
if [ -n "$LATEST_ARC" ] && [ "$CUR_ARC" != "$LATEST_ARC" ]; then
  log_step "Updating Actions Runner Controller & Runner ScaleSets: $CUR_ARC -> $LATEST_ARC"
  if [ "$DRY_RUN" = false ]; then
    log_info "Applying upstream ARC 0.15.x CRDs server-side..."
    for crd in autoscalinglisteners autoscalingrunnersets ephemeralrunners ephemeralrunnersets; do
      kubectl apply --server-side=true --force-conflicts -f "https://raw.githubusercontent.com/actions/actions-runner-controller/gha-runner-scale-set-${LATEST_ARC}/charts/gha-runner-scale-set-controller/crds/actions.github.com_${crd}.yaml"
    done

    # Update controller deployment
    sed -i "s|image: \"ghcr.io/actions/gha-runner-scale-set-controller:.*\"|image: \"ghcr.io/actions/gha-runner-scale-set-controller:${LATEST_ARC}\"|" dev-infra/actions-runner/controller/deployment.yaml
    sed -i "s|value: \"ghcr.io/actions/gha-runner-scale-set-controller:.*\"|value: \"ghcr.io/actions/gha-runner-scale-set-controller:${LATEST_ARC}\"|" dev-infra/actions-runner/controller/deployment.yaml

    # Update runner scale set version labels (strict parity requirement)
    sed -i "s|app.kubernetes.io/version: \".*\"|app.kubernetes.io/version: \"${LATEST_ARC}\"|g" dev-infra/actions-runner/runners/runner-amd64.yaml
    sed -i "s|app.kubernetes.io/version: \".*\"|app.kubernetes.io/version: \"${LATEST_ARC}\"|g" dev-infra/actions-runner/runners/runner-arm64.yaml

    kubectl apply -k dev-infra/actions-runner/
    kubectl rollout status deployment/arc-controller-gha-rs-controller -n dev-infra --timeout=180s
    MODIFIED_FILES+=("dev-infra/actions-runner/controller/deployment.yaml" "dev-infra/actions-runner/runners/runner-amd64.yaml" "dev-infra/actions-runner/runners/runner-arm64.yaml")
  fi
  UPDATED_COMPONENTS+=("arc-controller & runners: $CUR_ARC -> $LATEST_ARC")
fi

# ------------------------------------------------------------------------------
# 7. Open-WebUI & Playwright
# ------------------------------------------------------------------------------
OWUI_NEEDS_UPDATE=false
if [ -n "$LATEST_OWUI" ] && [ "$CUR_OWUI" != "$LATEST_OWUI" ]; then
  OWUI_NEEDS_UPDATE=true
fi

PLAYWRIGHT_NEEDS_UPDATE=false
if [ -n "$TARGET_PLAYWRIGHT_VER" ] && [ "$CUR_PLAYWRIGHT" != "$TARGET_PLAYWRIGHT" ]; then
  PLAYWRIGHT_NEEDS_UPDATE=true
fi

if [ "$OWUI_NEEDS_UPDATE" = true ] || [ "$PLAYWRIGHT_NEEDS_UPDATE" = true ]; then
  log_step "Updating Open-WebUI ($CUR_OWUI -> $LATEST_OWUI) & Playwright ($CUR_PLAYWRIGHT -> $TARGET_PLAYWRIGHT)"
  if [ "$DRY_RUN" = false ]; then
    if [ "$PLAYWRIGHT_NEEDS_UPDATE" = true ]; then
      sed -i "s|image: mcr.microsoft.com/playwright/python:.*|image: mcr.microsoft.com/playwright/python:${TARGET_PLAYWRIGHT}|" llm/playwright/deployment.yaml
      kubectl apply -k llm/playwright/
      kubectl rollout status deployment/playwright -n llm --timeout=180s
      MODIFIED_FILES+=("llm/playwright/deployment.yaml")
      UPDATED_COMPONENTS+=("playwright: $CUR_PLAYWRIGHT -> $TARGET_PLAYWRIGHT")
    fi

    if [ "$OWUI_NEEDS_UPDATE" = true ]; then
      sed -i "s|image: ghcr.io/open-webui/open-webui:.*|image: ghcr.io/open-webui/open-webui:${LATEST_OWUI}|" llm/open-webui/deployment.yaml
      kubectl apply -k llm/open-webui/
      kubectl rollout status deployment/open-webui -n llm --timeout=300s
      MODIFIED_FILES+=("llm/open-webui/deployment.yaml")
      UPDATED_COMPONENTS+=("open-webui: $CUR_OWUI -> $LATEST_OWUI")
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 8. Zot OCI Registry
# ------------------------------------------------------------------------------
if [ -n "$LATEST_ZOT" ] && [ "$CUR_ZOT" != "$LATEST_ZOT" ]; then
  log_step "Updating Zot Registry: $CUR_ZOT -> $LATEST_ZOT"
  if [ "$DRY_RUN" = false ]; then
    sed -i "s|image: ghcr.io/project-zot/zot:.*|image: ghcr.io/project-zot/zot:${LATEST_ZOT}|" dev-infra/registry/deployment.yaml
    kubectl apply -k dev-infra/registry/
    kubectl rollout status deployment/zot -n dev-infra --timeout=180s
    MODIFIED_FILES+=("dev-infra/registry/deployment.yaml")
  fi
  UPDATED_COMPONENTS+=("zot: $CUR_ZOT -> $LATEST_ZOT")
fi

# ------------------------------------------------------------------------------
# 9. System Upgrade Controller
# ------------------------------------------------------------------------------
if [ -n "$LATEST_SUC" ] && [ "$CUR_SUC" != "$LATEST_SUC" ]; then
  log_step "Updating System Upgrade Controller: $CUR_SUC -> $LATEST_SUC"
  if [ "$DRY_RUN" = false ]; then
    sed -i "s|image: rancher/system-upgrade-controller:.*|image: rancher/system-upgrade-controller:${LATEST_SUC}|" system-upgrade/deployment.yaml
    kubectl apply -f system-upgrade/deployment.yaml
    kubectl rollout status deployment/system-upgrade-controller -n system-upgrade --timeout=180s
    MODIFIED_FILES+=("system-upgrade/deployment.yaml")
  fi
  UPDATED_COMPONENTS+=("system-upgrade-controller: $CUR_SUC -> $LATEST_SUC")
fi

# ------------------------------------------------------------------------------
# Check If Any Updates Occurred
# ------------------------------------------------------------------------------
if [ ${#UPDATED_COMPONENTS[@]} -eq 0 ]; then
  log_success "All container images are already up to date! Nothing to do."
  exit 0
fi

if [ "$DRY_RUN" = true ]; then
  log_info "DRY RUN COMPLETE. The following updates would be applied:"
  for item in "${UPDATED_COMPONENTS[@]}"; do
    echo "  - $item"
  done
  exit 0
fi

# ------------------------------------------------------------------------------
# Post-Rollout Endpoint Verification
# ------------------------------------------------------------------------------
if [ "$SKIP_HEALTH" = false ]; then
  log_step "Running post-upgrade endpoint health checks"
  WORKER_IP="192.168.2.7"

  # Test Radar (NodePort/LB 32054)
  RADAR_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://${WORKER_IP}:32054/" || true)
  if [ "$RADAR_CODE" = "200" ]; then
    log_success "Radar endpoint reachable (HTTP $RADAR_CODE)"
  else
    log_warn "Radar endpoint probe returned HTTP $RADAR_CODE"
  fi

  # Test Grafana via Traefik ingress
  GRAFANA_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -H "Host: grafana.ddellspe.dev" "http://${WORKER_IP}/api/health" || true)
  if [ "$GRAFANA_CODE" = "200" ]; then
    log_success "Grafana endpoint reachable (HTTP $GRAFANA_CODE)"
  else
    log_warn "Grafana endpoint probe returned HTTP $GRAFANA_CODE"
  fi

  # Test Open-WebUI via Traefik ingress
  OWUI_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -H "Host: chat.ddellspe.dev" "http://${WORKER_IP}/health" || true)
  if [ "$OWUI_CODE" = "200" ]; then
    log_success "Open-WebUI endpoint reachable (HTTP $OWUI_CODE)"
  else
    log_warn "Open-WebUI endpoint probe returned HTTP $OWUI_CODE"
  fi
fi

# ------------------------------------------------------------------------------
# Git Commit & Push
# ------------------------------------------------------------------------------
if [ "$DO_COMMIT" = true ] && [ ${#MODIFIED_FILES[@]} -gt 0 ]; then
  log_step "Staging and committing updated manifests to Git"
  
  # Deduplicate modified files
  UNIQUE_FILES=($(echo "${MODIFIED_FILES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
  git add "${UNIQUE_FILES[@]}"

  # Construct semantic commit message
  COMMIT_TITLE="chore(images): update container images"
  COMMIT_BODY="Automated container upgrades:
"
  for comp in "${UPDATED_COMPONENTS[@]}"; do
    COMMIT_BODY="${COMMIT_BODY}
- ${comp}"
  done

  git commit -m "$COMMIT_TITLE" -m "$COMMIT_BODY"
  log_success "Created Git commit with updated manifests."

  if [ "$DO_PUSH" = true ]; then
    log_info "Pushing commit to origin main..."
    git push origin main
    log_success "Pushed commit to origin/main successfully."
  else
    log_info "Skipping git push (--no-push requested)."
  fi
fi

log_step "Container image upgrade routine complete!"
echo -e "${GREEN}${BOLD}Updated components:${NC}"
for item in "${UPDATED_COMPONENTS[@]}"; do
  echo -e "  ${GREEN}✓${NC} $item"
done
EOF
