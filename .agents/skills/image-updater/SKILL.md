---
name: image-updater
description: >-
  Audits, updates, and verifies container images across k3s-cluster Kubernetes manifests,
  respecting critical inter-service dependencies like Open-WebUI and Playwright version pairing,
  multi-architecture (ARM64/AMD64) compatibility, CRD migrations, and APU hardware requirements.
---

# Kubernetes Cluster Image Updater

This skill defines the operational runbook and safety requirements for auditing, upgrading, and verifying container images across the `k3s-cluster` repository.

## Quick Start: Auditing Updates

Run the automated update checker script from the repository root:
```bash
.agents/skills/image-updater/scripts/check-updates.sh
```
This script queries upstream GitHub, Docker Hub, and GHCR registries, inspects current repository manifests, and outputs an actionable status table highlighting available upgrades and version constraints.

---

## Critical Inter-Service Dependencies & Rules

### 1. Open-WebUI and Playwright Version Coupling
Open-WebUI uses Playwright for web scraping and browsing capabilities. Playwright enforces strict driver protocol compatibility between its Python client library and the remote browser server.

- **Constraint**: The `image:` tag in [llm/playwright/deployment.yaml](file:///mnt/c/Users/david/workspace/k3s-cluster/llm/playwright/deployment.yaml) (`mcr.microsoft.com/playwright/python:v<VERSION>-noble`) **MUST** match the `playwright==<VERSION>` dependency pinned inside Open-WebUI's `pyproject.toml` or `requirements.txt`.
- **How to verify**:
  ```bash
  curl -s "https://raw.githubusercontent.com/open-webui/open-webui/<TARGET_TAG>/pyproject.toml" | grep -i playwright
  ```
- **Rule**: Never update Playwright independently to a newer version than Open-WebUI supports. Only upgrade Playwright when Open-WebUI is upgraded and bumps its pinned dependency.

### 2. Open-WebUI Startup Patches
Open-WebUI runs custom startup patches defined in [llm/open-webui/configmap-patch.yaml](file:///mnt/c/Users/david/workspace/k3s-cluster/llm/open-webui/configmap-patch.yaml) (e.g. aspect ratio preservation for FLUX.2, LiteLLM audio routing, and SQLite config persistence).
- When upgrading Open-WebUI, verify that target files (such as `open_webui/routers/images.py` and `open_webui/routers/audio/__init__.py`) still match expected patterns.
- Ensure the patch script gracefully handles path transitions (e.g., `audio.py` turning into package `audio/__init__.py`).

### 3. Actions Runner Controller (ARC) & CRDs
The GitHub Actions Runner ScaleSet Controller ([dev-infra/actions-runner/controller/deployment.yaml](file:///mnt/c/Users/david/workspace/k3s-cluster/dev-infra/actions-runner/controller/deployment.yaml)) manages ephemeral runners.
- When updating `ghcr.io/actions/gha-runner-scale-set-controller`, verify if upstream CRDs changed:
  ```bash
  curl -s "https://api.github.com/repos/actions/actions-runner-controller/compare/gha-runner-scale-set-<OLD>...gha-runner-scale-set-<NEW>" | jq '.files[].filename'
  ```
- If CRDs changed, apply the new CRD definitions from upstream:
  ```bash
  for crd in autoscalinglisteners autoscalingrunnersets ephemeralrunners ephemeralrunnersets; do
    kubectl apply -f "https://raw.githubusercontent.com/actions/actions-runner-controller/gha-runner-scale-set-<NEW>/charts/gha-runner-scale-set-controller/crds/actions.github.com_${crd}.yaml"
  done
  ```

### 4. Kubernetes Helper Utilities Alignment
Manifests executing direct `kubectl` operations (such as [infra/pod-remediator/deployment.yaml](file:///mnt/c/Users/david/workspace/k3s-cluster/infra/pod-remediator/deployment.yaml) and [system-upgrade/cronjob.yaml](file:///mnt/c/Users/david/workspace/k3s-cluster/system-upgrade/cronjob.yaml)) use `alpine/k8s:<version>`.
- **Rule**: Track the active Kubernetes version of the cluster nodes (`status.nodeInfo.kubeletVersion`, e.g., `1.37.1`). Do not use outdated kubectl binaries that could lack modern CLI flags or admission schema support.

### 5. Multi-Architecture Compatibility (ARM64 + AMD64)
- Nodes `coupe`, `highball`, `rocks` (Raspberry Pi 4) and `well` (Raspberry Pi 5) are `linux/arm64`.
- Node `distiller` (AMD Strix Halo APU) is `linux/amd64`.
- Any image running cluster-wide (DaemonSets like `node-exporter`, controller pods, ingress, storage provisioner) or scheduled to worker `well` MUST have multi-architecture OCI manifests supporting both `arm64` and `amd64`.

### 6. Hardware-Specific ROCm Images (Strix Halo APU)
- Images like `docker.io/vllm/vllm-omni-rocm` or `vllm-openai-rocm` on `distiller` are built with specific AMD ROCm toolchains compatible with the Strix Halo RDNA 3.5 architecture (GFX1151).
- **Rule**: Do not blindly update these images to arbitrary tags without empirical ROCm hardware verification.

### 7. Databases
- PostgreSQL instances (`llm/postgres` and `buyoutyourcoach/postgres`) use `postgres:17-alpine`.
- Minor patch updates within the 17.x line occur automatically when restarted. Do not bump major versions (e.g., to 18) without running `pg_upgrade` or data migration.

---

## Step-by-Step Update Workflow

1. **Audit & Plan**:
   Run `.agents/skills/image-updater/scripts/check-updates.sh` to determine eligible candidates.

2. **Verify Architecture & Pairing**:
   - Confirm target tags exist and support the required architectures.
   - For Open-WebUI, verify Playwright compatibility.

3. **Apply Manifest Edits**:
   Update image tags in the relevant YAML manifests (`deployment.yaml`, `daemonset.yaml`, `cronjob.yaml`).

4. **Deploy & Rollout Verification**:
   Apply manifests via kustomize:
   ```bash
   kubectl apply -k <directory>/
   ```
   Watch the rollout:
   ```bash
   kubectl rollout status deployment/<name> -n <namespace> --timeout=180s
   ```

5. **Health & Log Audit**:
   Verify pod health, check for crashloops, and review startup logs:
   ```bash
   kubectl get pods -n <namespace>
   kubectl logs deployment/<name> -n <namespace> --tail=50
   ```

6. **Git Commit & Push**:
   Commit the updated manifests with clear semantic messages (e.g., `chore(images): update open-webui to v0.12.0, prometheus to v3.15.0, ...`).
