#!/usr/bin/env bash
set -e

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking Container Image Updates for k3s-cluster ===${NC}\n"

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
    grep -oE 'playwright==[0-9]+\.[0-9]+\.[0-9]+' | cut -d'=' -f3 || echo "unknown"
}

fetch_dockerhub_alpine_k8s() {
  curl -s "https://hub.docker.com/v2/repositories/alpine/k8s/tags?page_size=25" | \
    jq -r '.results[].name' 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1
}

# 1. Open-WebUI & Playwright
CUR_OWUI=$(grep -oE 'image: ghcr.io/open-webui/open-webui:.*' llm/open-webui/deployment.yaml | awk -F: '{print $3}')
LATEST_OWUI=$(fetch_github_latest "open-webui/open-webui")
CUR_PLAYWRIGHT=$(grep -oE 'image: mcr.microsoft.com/playwright/python:.*' llm/playwright/deployment.yaml | awk -F: '{print $3}')
REQ_PLAYWRIGHT=$(fetch_openwebui_playwright_req "$LATEST_OWUI")

# 2. ARC Controller
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

# 10. Alpine/k8s
CUR_ALPINE_K8S=$(grep -oE 'image: alpine/k8s:.*' infra/pod-remediator/deployment.yaml | awk -F: '{print $3}')
LATEST_ALPINE_K8S=$(fetch_dockerhub_alpine_k8s)

print_row() {
  local item="$1"
  local cur="$2"
  local lat="$3"
  local note="$4"
  if [ "$cur" = "$lat" ]; then
    printf "| %-32s | %-16s | %-16s | ${GREEN}%-10s${NC} | %-35s |\n" "$item" "$cur" "$lat" "Up to date" "$note"
  else
    printf "| %-32s | %-16s | %-16s | ${YELLOW}%-10s${NC} | %-35s |\n" "$item" "$cur" "$lat" "UPDATE" "$note"
  fi
}

echo "| Component                        | Current Version  | Latest Version   | Status     | Notes                               |"
echo "|----------------------------------|------------------|------------------|------------|-------------------------------------|"
print_row "Open-WebUI" "$CUR_OWUI" "$LATEST_OWUI" "Requires patch_images.py check"
print_row "Playwright (Python)" "$CUR_PLAYWRIGHT" "v${REQ_PLAYWRIGHT}-noble" "Pinned to Open-WebUI requirements"
print_row "ARC ScaleSet Controller" "$CUR_ARC" "$LATEST_ARC" "Requires CRD update check"
print_row "Zot OCI Registry" "$CUR_ZOT" "$LATEST_ZOT" "Patch update"
print_row "Grafana" "$CUR_GRAFANA" "$LATEST_GRAFANA" "Patch update"
print_row "Prometheus" "$CUR_PROM" "$LATEST_PROM" "Minor update"
print_row "Prometheus Config Reloader" "$CUR_RELOADER" "$LATEST_RELOADER" "Patch update"
print_row "Node Exporter" "$CUR_NODE_EXP" "$LATEST_NODE_EXP" "Up to date"
print_row "Skyhook Radar" "$CUR_RADAR" "$LATEST_RADAR" "Minor update"
print_row "System Upgrade Controller" "$CUR_SUC" "$LATEST_SUC" "Patch update"
print_row "Alpine k8s helper" "$CUR_ALPINE_K8S" "$LATEST_ALPINE_K8S" "Aligns with cluster k8s version"
