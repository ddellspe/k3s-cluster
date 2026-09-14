# K3s Cluster Manifests & Configurations

This repository contains the complete set of Kubernetes manifests, Helm values, and configuration files deployed across the remote K3s cluster. Manifests are split into dedicated resource kinds per workload and organized with Kustomize for streamlined GitOps and cluster management.

## Directory Structure

```text
k3s-cluster/
├── buyoutyourcoach/                      # Buyout Your Coach NCAA Tracker (namespace: buyoutyourcoach)
│   ├── kustomization.yaml                 # Aggregated buyoutyourcoach kustomization
│   ├── namespace.yaml                     # buyoutyourcoach namespace definition
│   ├── postgres/                          # PostgreSQL 17 StatefulSet, Service, and Secret
│   │   ├── statefulset.yaml               # Pinned to well with 10Gi local-path storage
│   │   ├── service.yaml                   # ClusterIP port 5432
│   │   ├── secret.yaml                    # Database credentials
│   │   └── kustomization.yaml
│   └── app/                               # Next.js Application (Deployment, Service, PVC, Ingress)
│       ├── deployment.yaml                # App pinned to well with local-path data volume & DB env
│       ├── pvc.yaml                       # 5Gi on local-path for /app/data
│       ├── service.yaml                   # ClusterIP port 3000
│       ├── ingress.yaml                   # Internal ingress: byc.ddellspe.dev (ddellspe-tls)
│       ├── ingress-external.yaml          # Public ingress: buyoutyourcoach.com (leresolver)
│       └── kustomization.yaml
├── dev-infra/                             # Developer infrastructure & CI/CD (namespace: dev-infra)
│   ├── kustomization.yaml                 # Aggregated dev-infra kustomization
│   ├── namespace.yaml                     # dev-infra namespace definition
│   ├── registry/                          # Zot OCI Registry & Web UI (PVC, Deployment, Service, Ingress)
│   │   ├── config.json                    # Standalone Zot configuration (OCI 1.1, search, UI enabled)
│   │   ├── deployment.yaml                # Zot v2.1.21 pinned to distiller (3.7 TB NVMe)
│   │   ├── pvc.yaml                       # 100Gi on local-path
│   │   ├── service.yaml                   # ClusterIP port 5000
│   │   ├── ingress.yaml                   # registry.ddellspe.dev (ddellspe-tls)
│   │   └── kustomization.yaml
│   └── actions-runner/                    # GitHub Actions Runner Controller (ARC) & Multi-Arch Scale Sets
│       ├── kustomization.yaml
│       ├── controller/                    # ARC Controller Manager (v0.14.2)
│       │   ├── deployment.yaml
│       │   ├── rbac.yaml
│       │   ├── serviceaccount.yaml
│       │   └── kustomization.yaml
│       └── runners/                       # DinD Multi-Arch Autoscaling Runner Sets
│           ├── runner-amd64.yaml          # arc-runner-amd64 pinned to distiller (DinD)
│           ├── runner-arm64.yaml          # arc-runner-arm64 pinned to well (DinD)
│           └── kustomization.yaml
├── kube-system/                           # Cluster-wide system configurations
│   └── coredns/                           # CoreDNS custom rules (wildcard search-domain interceptor)
│       ├── coredns-custom.yaml
│       └── kustomization.yaml
├── llm/                                   # Accelerated LLM inference & AI gateway stack (namespace: llm)
│   ├── kustomization.yaml                 # Aggregated LLM namespace kustomization
│   ├── llm-gemma/                         # Dual Gemma 4 (26B + 12B) via ROCm vLLM (Deployment, Services)
│   │   ├── deployment.yaml
│   │   ├── service-12b.yaml
│   │   ├── service-26b.yaml
│   │   └── kustomization.yaml
│   ├── llm-nemotron/                      # Nemotron 3.5 Lightning 30B GGUF via llama.cpp (Deployment, Service)
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   ├── llm-qwen36/                        # Qwen 3.6 35B A3B GGUF via llama.cpp (Deployment, Service)
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   ├── llm-router/                        # LiteLLM Router (Config, Deployment, Service, Ingress)
│   │   ├── config.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   └── kustomization.yaml
│   ├── open-webui/                        # Open WebUI with RAG & Tool Integration (Deployment, Service, Ingress)
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   ├── ingress-external.yaml
│   │   └── kustomization.yaml
│   ├── playwright/                        # Playwright Headless Browser WebSocket Server (Deployment, Service)
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── searxng/                           # SearXNG Metasearch Engine (Settings Template, Deployment, Service, Ingress)
│       ├── settings.yml.example           # Example SearXNG settings template (actual mounted via Secret)
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       └── kustomization.yaml
├── monitoring/
│   ├── kustomization.yaml                 # Aggregated monitoring kustomization
│   ├── caretta/                           # Caretta eBPF K8s network & service map (DaemonSet, VM, Grafana)
│   │   ├── daemonset.yaml
│   │   ├── statefulset-vm.yaml
│   │   ├── deployment-grafana.yaml
│   │   ├── services.yaml
│   │   ├── configmaps.yaml
│   │   ├── secret.yaml
│   │   ├── rbac.yaml
│   │   ├── values.yaml
│   │   └── kustomization.yaml
│   ├── grafana/                           # Grafana (Datasources, PVC, Deployment, Service, Ingress)
│   │   ├── datasources.yaml
│   │   ├── pvc.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   ├── ingress-external.yaml
│   │   └── kustomization.yaml
│   ├── node-exporter/                     # Prometheus Node Exporter (DaemonSet, Service)
│   │   ├── daemonset.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── prometheus/                        # Prometheus Server (Prometheus Config, PVC, Deployment, Service, Ingress)
│       ├── prometheus.yml
│       ├── pvc.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       └── kustomization.yaml
├── radar/                                 # Radar cluster inspection UI (Deployment, Service, Ingress)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml
└── system-upgrade/                        # Rancher System Upgrade Controller & Auto-Updater
    ├── deployment.yaml                    # System Upgrade Controller Deployment
    ├── cronjob.yaml                       # Automated weekly K3s version upgrade check
    ├── plan.yaml                          # K3s server upgrade Plan
    └── kustomization.yaml
```

## Namespaces & Workloads

| Namespace | Workloads | Domain / Endpoint |
| :--- | :--- | :--- |
| **`buyoutyourcoach`** | Next.js NCAA Coach Buyout Tracker, PostgreSQL 17 StatefulSet | `byc.ddellspe.dev` (internal), `buyoutyourcoach.com` (public) |
| **`dev-infra`** | Zot OCI Registry (Images & Helm charts), GitHub Actions Runner Controller (ARC) | `registry.ddellspe.dev` |
| **`llm`** | Dual Gemma 4 (26B & 12B via vLLM), Nemotron 3.5 (GGUF), Qwen 3.6 (GGUF), LiteLLM Router, Open WebUI, SearXNG, Playwright | `chat.ddellspe.dev`, `llm.ddellspe.dev`, `searxng.ddellspe.dev` |
| **`monitoring`** | Prometheus Server, Grafana, Node Exporter, Caretta (eBPF Service Map) | `grafana.ddellspe.dev`, `prometheus.ddellspe.dev` |
| **`radar`** | Radar Kubernetes Dashboard | `radar.ddellspe.dev` |
| **`kube-system`** | CoreDNS custom configuration (`coredns-custom`) | Cluster-wide DNS routing |
| **`system-upgrade`**| system-upgrade-controller, auto-updater cron | Automated weekly K3s version upgrades |

## GPU Resource Management & Model Concurrency (`distiller`)

The cluster's accelerated inference models run on node **`distiller`** (AMD Strix Halo APU with 128 GB unified LPDDR5X memory, ~122.8 GiB allocatable).

### Memory Footprint & Concurrency

#### Active Dual-Model Deployment (`llm-gemma`)
The primary deployment runs **dual Google Gemma 4 models concurrently** using native ROCm vLLM inside a single multi-container pod (`llm-gemma`):
- **`google/gemma-4-26B-A4B-it`** (vLLM server on port `8000`):
  - **GPU Memory Utilization:** `0.48` (~48% GPU memory)
  - **KV Cache Buffer:** `6 GiB` (`--kv-cache-memory-bytes 6G`)
  - **Context Window:** `32,768` tokens (`--max-model-len 32768`)
  - **K8s Resources:** Requests `52 GiB` RAM / 4 CPU; Limits `80 GiB` RAM / 16 CPU
- **`google/gemma-4-12B-it`** (vLLM server on port `8001`):
  - **GPU Memory Utilization:** `0.28` (~28% GPU memory)
  - **KV Cache Buffer:** `8 GiB` (`--kv-cache-memory-bytes 8G`)
  - **Context Window:** `32,768` tokens (`--max-model-len 32768`)
  - **K8s Resources:** Requests `25 GiB` RAM / 2 CPU; Limits `35 GiB` RAM / 8 CPU
- **Combined Active Footprint:**
  - **GPU Memory Utilization Pool:** `0.48 + 0.28 = 0.76` (~76% of Strix Halo unified VRAM pool)
  - **Total K8s Memory Request:** `77 GiB` (62% of allocatable node memory)
  - **Total K8s Memory Limit:** `115 GiB` (94% of allocatable node memory)
  - **Headroom:** Leaves ~45 GiB of allocatable headroom below requests, and a ~10–13 GiB cushion at limits for the OS kernel, I/O caches, and system daemons (`node-exporter`, `caretta` eBPF).

#### Standby / Alternative Models (`replicas: 0`)
Alternative models are kept defined in the repository and cluster, but scaled to `0` by default to preserve GPU memory:
- **`llm-nemotron`** (NVIDIA Nemotron 3.5 Lightning 30B A3B `Q8_0` GGUF):
  - Engine: `llama.cpp` ROCm server (`ghcr.io/ggml-org/llama.cpp:server-rocm`, port `8000`)
  - Context & Reasoning: `65,536` tokens (`-c 65536`), FlashAttention enabled (`-fa on`), `--reasoning-budget 8192`
  - Memory Footprint: Requests `40 GiB`, Limits `52 GiB` (~31.7 GiB unified VRAM)
- **`llm-qwen36`** (Qwen 3.6 35B A3B `MXFP4_MOE` GGUF):
  - Engine: `llama.cpp` ROCm server (`ghcr.io/ggml-org/llama.cpp:server-rocm`, port `8000`)
  - Context & Reasoning: `65,536` tokens (`-c 65536`), FlashAttention enabled (`-fa on`), `--reasoning-budget 8192`
  - Memory Footprint: Requests `25 GiB`, Limits `36 GiB`

### Deployment Strategy
- All LLM deployment manifests use `strategy.type: Recreate` so that updates to an existing deployment terminate the old pod before spinning up the new one, preventing concurrent GPU memory contention during rollouts.

### Switching / Scaling Models
Models can be scaled dynamically:

```bash
# 1. Scale down current active model
kubectl scale deployment/llm-gemma -n llm --replicas=0

# 2. Scale up target alternative model
kubectl scale deployment/llm-qwen36 -n llm --replicas=1
# OR
# kubectl scale deployment/llm-nemotron -n llm --replicas=1
```

> **Selective Toggling in `llm-gemma`:** If you want to run only one of the two Gemma models inside `llm-gemma` to free memory, set `ENABLE_26B: "false"` or `ENABLE_12B: "false"` in [`llm/llm-gemma/deployment.yaml`](llm/llm-gemma/deployment.yaml). The disabled container starts a lightweight Python HTTP stub instead of loading weights into VRAM.

### LiteLLM Router Dynamic Health Checks & Routing
- The LiteLLM Router routes between the active backends:
  - `google/gemma-4-26B-A4B-it` via `hosted_vllm` (`http://llm-gemma26b-service.llm:8000/v1`)
  - `google/gemma-4-12b-it` via `hosted_vllm` (`http://llm-gemma12b-service.llm:8001/v1`)
- Both model configurations support native reasoning and function calling (`supports_reasoning: true`, `supports_function_calling: true`).
- LiteLLM uses `usage-based-routing-v2` and dynamically probes `/health` endpoints. When a model backend is disabled or scaled down, LiteLLM marks the backend unavailable without dropping in-flight requests.

## Deployment Examples

Deploy an entire namespace using Kustomize:
```bash
kubectl apply -k buyoutyourcoach/
kubectl apply -k dev-infra/
kubectl apply -k llm/
kubectl apply -k monitoring/
kubectl apply -k kube-system/coredns/
```

Deploy a specific workload:
```bash
kubectl apply -k buyoutyourcoach/postgres/
kubectl apply -k buyoutyourcoach/app/
kubectl apply -k dev-infra/registry/
kubectl apply -k dev-infra/actions-runner/
kubectl apply -k llm/open-webui/
kubectl apply -k llm/playwright/
kubectl apply -k monitoring/grafana/
kubectl apply -k monitoring/prometheus/
```

## Modifying Configurations & Applying Changes

Configuration files are extracted into standalone, standard YAML files (`prometheus.yml`, `datasources.yaml`, `config.yaml`, `coredns-custom.yaml`) and packaged into ConfigMaps/Secrets.

### 1. CoreDNS Custom Configuration (`kube-system/coredns`)
K3s automatically imports `/etc/coredns/custom/*.server` and `*.override` from the `coredns-custom` ConfigMap in `kube-system`.
- **Purpose**: Prevents Linux `ndots:5` search-domain appends (e.g. `pypi.org.ddellspe.net`) from colliding with the network's `*.ddellspe.net` wildcard DNS record.
- **Rules**: Multi-label queries (`*.*.ddellspe.net`) return `NXDOMAIN` via the CoreDNS `template` plugin with fallthrough, immediately forcing `glibc` to query the root public domain directly, while legitimate single-label local services (`chat.ddellspe.net`, `radar.ddellspe.dev`) resolve cleanly.
- **Deploying & Reloading**:
  ```bash
  kubectl apply -k kube-system/coredns/
  kubectl rollout restart deployment/coredns -n kube-system
  ```

### 2. Prometheus Configuration Updates
1. Edit [`monitoring/prometheus/prometheus.yml`](monitoring/prometheus/prometheus.yml).
2. Deploy the change:
   ```bash
   kubectl apply -k monitoring/prometheus/
   ```
3. **Reload Behavior**: The `config-reloader` sidecar detects the updated file and triggers a live reload (`/-/reload`) automatically with zero downtime.
   - *Manual reload trigger (optional)*:
     ```bash
     kubectl exec -n monitoring deploy/prometheus -c prometheus -- wget -qO- --post-data="" http://127.0.0.1:9090/-/reload
     ```

### 3. Other ConfigMap Services (Grafana, LLM Router)
1. Edit the respective config file:
   - Grafana Datasources: [`monitoring/grafana/datasources.yaml`](monitoring/grafana/datasources.yaml)
   - LiteLLM Router: [`llm/llm-router/config.yaml`](llm/llm-router/config.yaml)
2. Deploy the updated ConfigMap:
   ```bash
   kubectl apply -k monitoring/grafana/
   kubectl apply -k llm/llm-router/
   ```
3. **Reload Behavior**: Services read their configuration on process startup. Force them to take the new configuration by triggering a rolling restart:
   ```bash
   kubectl rollout restart deployment/grafana -n monitoring
   kubectl rollout restart deployment/llm-router -n llm
   ```

### 4. SearXNG Configuration Workflow (Secret-Based)

SearXNG settings and credentials are kept out of Git and managed entirely via Kubernetes Secrets:
- **`searxng-secret`**: Stores the cryptographic session secret key (`SEARXNG_SECRET` env var).
- **`searxng-config`**: Mounts `/etc/searxng/settings.yml` containing the custom instance branding and Wikimedia-compliant `useragent_suffix` (contact email).

#### Step-by-Step SearXNG Workflow:
1. **Initial Setup / Local Config File**:
   Copy the example template into the gitignored `.secrets/` directory:
   ```bash
   cp llm/searxng/settings.yml.example .secrets/searxng-settings.yml
   ```
2. **Edit Settings**:
   Modify `.secrets/searxng-settings.yml` (e.g. adjust `useragent_suffix`, search formats, autocomplete providers).
3. **Push Secret to Cluster**:
   ```bash
   kubectl create secret generic searxng-config -n llm \
     --from-file=settings.yml=.secrets/searxng-settings.yml \
     --dry-run=client -o yaml | kubectl apply -f -
   ```
4. **Restart SearXNG**:
   ```bash
   kubectl rollout restart deployment/searxng -n llm
   ```

### 5. Zot OCI Registry Configuration (`dev-infra/registry`)
Zot natively hosts both **container images** (Docker/OCI) and **Helm charts** (OCI artifacts) on node `distiller` (backed by a 100Gi `local-path` volume on high-speed NVMe storage).
- **Web UI & Endpoints**: Access the registry catalog and inspect image/chart tags at `https://registry.ddellspe.dev`.
- **Modifying Settings**:
  1. Edit [`dev-infra/registry/config.json`](dev-infra/registry/config.json).
  2. Deploy the updated ConfigMap:
     ```bash
     kubectl apply -k dev-infra/registry/
     ```
  3. Reload by triggering a rollout restart:
     ```bash
     kubectl rollout restart deployment/zot -n dev-infra
     ```
- **Pushing & Pulling Helm Charts**:
  ```bash
  helm package mychart/ -d .
  helm push mychart-0.1.0.tgz oci://registry.ddellspe.dev/charts
  helm show chart oci://registry.ddellspe.dev/charts/mychart --version 0.1.0
  ```
- **Pushing & Pulling Container Images**:
  ```bash
  docker tag myapp:latest registry.ddellspe.dev/myapp:latest
  docker push registry.ddellspe.dev/myapp:latest
  ```

### 6. GitHub Actions Runner Controller (ARC) Multi-Arch Workflows (`dev-infra/actions-runner`)
Self-hosted runners are powered by GitHub's official modern Actions Runner Controller (`gha-runner-scale-set`), scoped to the `ddellspe-dev` GitHub Organization.
- **Autoscaling Behavior**: Scales down to 0 runner pods when idle. When a job targeting a scale set is queued in any repository under `ddellspe-dev`, ARC spins up an ephemeral pod with a Docker-in-Docker sidecar, executes the job, and deletes the pod upon completion.
- **Available Runner Sets**:
  - **`arc-runner-amd64`**: Pinned to node `distiller` (AMD Strix Halo APU, 32 CPU cores, 128 GB RAM). Ideal for heavy builds, x86 image creation, and test suites.
  - **`arc-runner-arm64`**: Pinned to node `well` (Raspberry Pi 5 worker, 4 CPU cores, 16 GB RAM). Ideal for native ARM64 compilation and image builds.
- **Using Runners in Workflows (`.github/workflows/*.yml`)**:
  ```yaml
  name: Build and Push
  on: [push]

  jobs:
    build-amd64:
      runs-on: arc-runner-amd64
      steps:
        - uses: actions/checkout@v4
        - name: Build and Push Container
          run: |
            docker build -t registry.ddellspe.dev/my-app:amd64 .
            docker push registry.ddellspe.dev/my-app:amd64

    build-arm64:
      runs-on: arc-runner-arm64
      steps:
        - uses: actions/checkout@v4
        - name: Build Native ARM64 Container
          run: |
            docker build -t registry.ddellspe.dev/my-app:arm64 .
            docker push registry.ddellspe.dev/my-app:arm64
  ```

### 7. Buyout Your Coach NCAA Tracker (`buyoutyourcoach/`)

The NCAA Coach Buyout & Contract Tracker web application is deployed in the dedicated `buyoutyourcoach` namespace.
- **Application (`buyoutyourcoach/app`)**: Next.js 16 standalone server running `registry.ddellspe.dev/buyoutyourcoach:latest` pinned to worker node `well`. Backed by a 5Gi `local-path` persistent volume mounted at `/app/data` for persistence and cache storage. Configured with database environment variables pointing to internal PostgreSQL.
- **Database (`buyoutyourcoach/postgres`)**: PostgreSQL 17 StatefulSet pinned to worker node `well`, backed by a 10Gi `local-path` volume with health probes and automated initialization.
- **Internal Validation Ingress (`byc.ddellspe.dev`)**: Protected by the cluster wildcard Let's Encrypt certificate (`ddellspe-tls`) for testing and validation within the internal network.
- **Public Ingress (`buyoutyourcoach.com`)**: Configured with Traefik's automated Let's Encrypt ACME resolver (`leresolver`).
  - To activate public access once internal validation is confirmed:
    ```bash
    kubectl apply -f buyoutyourcoach/app/ingress-external.yaml
    ```
    *(Or uncomment `- ingress-external.yaml` in [`buyoutyourcoach/app/kustomization.yaml`](buyoutyourcoach/app/kustomization.yaml) and run `kubectl apply -k buyoutyourcoach/`)*.

## Managing Kubernetes Secrets

Secrets (API tokens, TLS certificates, credentials) are stored securely in the cluster and should never be committed to Git in plaintext.

### 1. Creating or Updating Secrets via `kubectl`

Use the idempotent `kubectl create ... --dry-run=client -o yaml | kubectl apply -f -` pattern to create or update secrets without erroring if they already exist:

#### HuggingFace Token (`hf-token-secret`)
Used by gated LLM model deployments (`llm-gemma`, `llm-nemotron`, `llm-qwen36`):
```bash
kubectl create secret generic hf-token-secret \
  --namespace=llm \
  --from-literal=token="hf_YourHuggingFaceTokenHere" \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### SearXNG Configuration & Secret Key (`searxng-config`, `searxng-secret`)
```bash
# SearXNG session encryption secret
kubectl create secret generic searxng-secret \
  --namespace=llm \
  --from-literal=secret-key="YourRandomSecretKeyHere" \
  --dry-run=client -o yaml | kubectl apply -f -

# SearXNG custom settings (including private user-agent / email)
kubectl create secret generic searxng-config \
  --namespace=llm \
  --from-file=settings.yml=.secrets/searxng-settings.yml \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### GitHub Actions Runner Controller Secret (`arc-runner-secret`)
Used by ARC runner scale sets in `dev-infra` to register runners in the `ddellspe-dev` GitHub Organization:
```bash
kubectl create secret generic arc-runner-secret \
  --namespace=dev-infra \
  --from-literal=github_token="ghp_YourPersonalAccessTokenHere" \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Generic Key-Value Secret
```bash
kubectl create secret generic <secret-name> \
  --namespace=<namespace> \
  --from-literal=<key>=<value> \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Secret from a Local File
```bash
kubectl create secret generic <secret-name> \
  --namespace=<namespace> \
  --from-file=<key>=/path/to/secret-file.txt \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### TLS Certificate Secret (`ddellspe-tls`)
```bash
kubectl create secret tls ddellspe-tls \
  --namespace=<namespace> \
  --cert=/path/to/tls.crt \
  --key=/path/to/tls.key \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 2. Managing Secrets via Kustomize (`secretGenerator`)

For local GitOps workflows where secret files are kept in a **gitignored** directory (e.g. `.secrets/`):

In your workload's `kustomization.yaml`:
```yaml
secretGenerator:
  - name: hf-token-secret
    files:
      - token=.secrets/hf-token.txt
    options:
      disableNameSuffixHash: true
```

### 3. Inspecting Cluster Secrets
```bash
# List secrets in a namespace
kubectl get secrets -n llm

# View secret keys (metadata only)
kubectl describe secret hf-token-secret -n llm

# Decode and inspect a secret value
kubectl get secret hf-token-secret -n llm -o jsonpath='{.data.token}' | base64 -d && echo
```
