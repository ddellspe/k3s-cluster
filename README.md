# K3s Cluster Manifests & Configurations

This repository contains the complete set of Kubernetes manifests, Helm values, and configuration files deployed across the remote K3s cluster. Manifests are split into dedicated resource kinds per workload and organized with Kustomize for streamlined GitOps and cluster management.

## Directory Structure

```text
k3s-cluster/
├── buyoutyourcoach/                      # Buyout Your Coach NCAA Tracker (namespace: buyoutyourcoach)
│   ├── kustomization.yaml                 # Aggregated buyoutyourcoach kustomization
│   ├── namespace.yaml                     # buyoutyourcoach namespace definition
│   ├── postgres/                          # PostgreSQL 17 StatefulSet, Service, and Secret
│   │   ├── statefulset.yaml               # Pinned to well with 10Gi storage-hot (NVMe)
│   │   ├── service.yaml                   # ClusterIP port 5432
│   │   ├── secret.yaml                    # Database credentials
│   │   └── kustomization.yaml
│   └── app/                               # Next.js Application (Deployment, Service, PVC, Ingress)
│       ├── deployment.yaml                # App pinned to well with storage-hot data volume & DB env
│       ├── pvc.yaml                       # 5Gi on storage-hot (NVMe) for /app/data
│       ├── service.yaml                   # ClusterIP port 3000
│       ├── ingress.yaml                   # Internal ingress: byc.ddellspe.dev (ddellspe-tls)
│       ├── ingress-external.yaml          # Public ingress: buyoutyourcoach.com (leresolver)
│       └── kustomization.yaml
├── dev-infra/                             # Developer infrastructure & CI/CD (namespace: dev-infra)
│   ├── kustomization.yaml                 # Aggregated dev-infra kustomization
│   ├── namespace.yaml                     # dev-infra namespace definition
│   ├── registry/                          # Zot OCI Registry & Web UI (PVC, Deployment, Service, Ingress)
│   │   ├── config.json                    # Standalone Zot configuration (OCI 1.1, search, UI enabled)
│   │   ├── deployment.yaml                # Zot v2.1.21 backed by storage-warm (Margarita NFS 220TB)
│   │   ├── pvc.yaml                       # 100Gi on storage-warm (RWX)
│   │   ├── service.yaml                   # ClusterIP port 5000
│   │   ├── ingress.yaml                   # registry.ddellspe.dev (ddellspe-tls)
│   │   └── kustomization.yaml
│   ├── actions-runner/                    # GitHub Actions Runner Controller (ARC) & Multi-Arch Scale Sets
│   │   ├── kustomization.yaml
│   │   ├── controller/                    # ARC Controller Manager (v0.14.2)
│   │   │   ├── deployment.yaml
│   │   │   ├── rbac.yaml
│   │   │   ├── serviceaccount.yaml
│   │   │   └── kustomization.yaml
│   │   └── runners/                       # DinD Multi-Arch Autoscaling Runner Sets
│   │       ├── runner-amd64.yaml          # arc-runner-amd64 pinned to distiller (DinD)
│   │       ├── runner-arm64.yaml          # arc-runner-arm64 pinned to well (DinD)
│   │       └── kustomization.yaml
│   └── keel/                              # Keel Automated Image Update Controller (Deployment, RBAC, Service)
│       ├── deployment.yaml                # Keel daemon pinned to distiller (polling trigger enabled)
│       ├── rbac.yaml                      # ClusterRole & ClusterRoleBinding
│       ├── serviceaccount.yaml
│       ├── service.yaml                   # ClusterIP port 9300
│       └── kustomization.yaml
├── infra/                                 # Cluster-wide infrastructure & storage provisioners
│   ├── kustomization.yaml                 # Aggregated infra kustomization
│   └── storage/                           # 3-Tier Storage Architecture (StorageClasses & NFS Provisioner)
│       ├── deployment.yaml                # nfs-subdir-external-provisioner (connected to Margarita NFS)
│       ├── rbac.yaml                      # Provisioner RBAC & ServiceAccount
│       ├── storage-hot.yaml               # HOT tier (NVMe on well, low-latency databases & TSDBs)
│       ├── storage-warm.yaml              # WARM tier (NFS on Margarita, 220TB high-capacity RWX)
│       ├── storage-cold.yaml              # COLD tier (local-path on Pis, low-power & read-heavy)
│       └── kustomization.yaml
├── kube-system/                           # Cluster-wide system configurations
│   ├── coredns/                           # CoreDNS custom rules (wildcard search-domain interceptor)
│   │   ├── coredns-custom.yaml
│   │   └── kustomization.yaml
│   └── traefik/                           # Traefik HelmChartConfig overrides (image version)
│       ├── helmchartconfig.yaml
│       └── kustomization.yaml
├── llm/                                   # Accelerated LLM inference & AI gateway stack (namespace: llm)
│   ├── kustomization.yaml                 # Aggregated LLM namespace kustomization
│   ├── postgres/                          # Dedicated PostgreSQL 17 for LiteLLM Admin UI
│   │   ├── statefulset.yaml               # Pinned to well with 10Gi storage-hot (NVMe)
│   │   ├── service.yaml                   # ClusterIP port 5432
│   │   └── kustomization.yaml
│   ├── flux/                              # FLUX.1-schnell Image Generation via ROCm vLLM-Omni
│   │   ├── deployment.yaml                # vllm-omni-rocm pinned to distiller (Strix Halo APU)
│   │   ├── service.yaml                   # ClusterIP port 8000 & NodePort 30810
│   │   ├── ingress.yaml                   # flux.ddellspe.dev (ddellspe-tls)
│   │   └── kustomization.yaml
│   ├── laya/                              # Fast "System 1" Decision Model via ROCm (ModernBERT-large)
│   │   ├── deployment.yaml                # ROCm accelerated ModernBERT/Laya service
│   │   ├── service.yaml                   # ClusterIP & NodePort 30800
│   │   ├── ingress.yaml                   # laya.ddellspe.dev (ddellspe-tls)
│   │   └── kustomization.yaml
│   ├── llm-gemma/                         # Google Gemma 4 (26B-A4B-it) via ROCm vLLM (Deployment, Service)
│   │   ├── deployment.yaml                # Native ROCm vLLM pinned to distiller (Strix Halo APU)
│   │   ├── service-26b.yaml               # ClusterIP port 8000
│   │   └── kustomization.yaml
│   ├── llm-router/                        # LiteLLM Router (Config, Deployment, Service, Ingress, Middleware)
│   │   ├── config.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   ├── middleware.yaml.example        # Traefik auto-auth header injection template for .dev domains
│   │   └── kustomization.yaml

│   ├── open-webui/                        # Open WebUI with RAG & Tool Integration (Deployment, PVC, Service, Ingress)
│   │   ├── deployment.yaml
│   │   ├── pvc.yaml                       # 10Gi on storage-hot (NVMe) for SQLite DB & uploads
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
│   │   ├── statefulset-vm.yaml            # VictoriaMetrics backed by 10Gi storage-hot (NVMe)
│   │   ├── deployment-grafana.yaml
│   │   ├── services.yaml
│   │   ├── configmaps.yaml
│   │   ├── secret.yaml
│   │   ├── rbac.yaml
│   │   ├── values.yaml
│   │   └── kustomization.yaml
│   ├── grafana/                           # Grafana (Datasources, PVC, Deployment, Service, Ingress)
│   │   ├── datasources.yaml
│   │   ├── pvc.yaml                       # 20Gi on storage-warm (NFS RWX)
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
│       ├── pvc.yaml                       # 60Gi on storage-hot (NVMe) for TSDB
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
| **`dev-infra`** | Zot OCI Registry (Images & Helm charts), GitHub Actions Runner Controller (ARC), Keel (Image Auto-Deployer) | `registry.ddellspe.dev` |
| **`infra`** | 3-Tier Storage Architecture (Hot/Warm/Cold StorageClasses, NFS Subdir Provisioner) | Cluster-wide storage |
| **`llm`** | Gemma 4 26B (vLLM ROCm), FLUX.1-schnell (vLLM-Omni ROCm), Laya Decision Model, LiteLLM Router, Open WebUI, SearXNG, Playwright | `chat.ddellspe.dev`, `llm.ddellspe.dev`, `flux.ddellspe.dev`, `laya.ddellspe.dev`, `searxng.ddellspe.dev` |
| **`monitoring`** | Prometheus Server, Grafana, Node Exporter, Caretta (eBPF Service Map) | `grafana.ddellspe.dev`, `prometheus.ddellspe.dev` |
| **`radar`** | Radar Kubernetes Dashboard | `radar.ddellspe.dev` |
| **`kube-system`** | CoreDNS custom configuration (`coredns-custom`), Traefik | Cluster-wide DNS & routing |
| **`system-upgrade`**| system-upgrade-controller, auto-updater cron | Automated weekly K3s version upgrades |

## GPU Resource Management & Model Concurrency (`distiller`)

The cluster's accelerated inference models run on node **`distiller`** (AMD Strix Halo APU with 128 GB unified LPDDR5X memory, ~122.8 GiB allocatable).

### Memory Footprint & Concurrency

#### Large Language Model (`llm-gemma`)
The primary chat model is **Google Gemma 4 (26B-A4B-it)** running via native ROCm vLLM inside [`llm/llm-gemma`](llm/llm-gemma/):
- **Model:** `google/gemma-4-26B-A4B-it` (vLLM server on port `8000`)
- **GPU Memory Utilization:** `0.48` (~48% GPU memory, reserving ~60 GiB unified VRAM with KV cache)
- **KV Cache Buffer:** `6 GiB` (`--kv-cache-memory-bytes 6G`)
- **Context Window:** `32,768` tokens (`--max-model-len 32768`)
- **K8s Resources:** Requests `52 GiB` RAM / 4 CPU; Limits `80 GiB` RAM / 16 CPU
- **Endpoint:** `http://llm-gemma26b-service.llm:8000`

#### Image Generation Model (`flux`)
High-resolution text-to-image synthesis is provided by **FLUX.1-schnell** running via `vllm-omni-rocm` inside [`llm/flux`](llm/flux/):
- **Model:** `black-forest-labs/FLUX.1-schnell` (serving port `8000`)
- **Container Image:** `docker.io/vllm/vllm-omni-rocm:v0.28.0`
- **ROCm Hardware Acceleration:** AMD Strix Halo APU (`distiller`, GFX1151) with `HSA_OVERRIDE_GFX_VERSION: "11.5.1"`, SDPA attention backend, and native BF16 execution.
- **Latency & Footprint:**
  - VRAM footprint: ~31.4 GiB in unified VRAM (model weights + diffusion state).
  - Generation speed: ~10s for 4-step 1024x1024 inference.
  - Resource allocation: Requests `25 GiB` RAM / 4 CPU; Limits `35 GiB` RAM / 16 CPU.
- **API Surface & Open-WebUI Integration:**
  - Provides OpenAI-compatible image generations API (`POST /v1/images/generations`).
  - Open-WebUI is configured to route image generation requests directly to `http://llm-flux-service.llm:8000/v1`.
- **Network Endpoints:**
  - Cluster Internal: `http://llm-flux-service.llm:8000`
  - NodePort Endpoint: `http://192.168.2.7:30810`
  - External Ingress: `https://flux.ddellspe.dev`

#### Fast "System 1" Decision Model (`laya`)
For instantaneous structured decision making (filtering, sentiment, binary classification, ranking rubrics, routing), the cluster hosts **Laya** (`convaiinnovations/laya`), a non-autoregressive decision model built on ModernBERT-large (~395M params):
- **Hardware Acceleration:** Native AMD ROCm HIP runtime on the AMD Strix Halo APU (`distiller`, GFX1151) with `HSA_OVERRIDE_GFX_VERSION: "11.5.1"`.
- **Preloaded Models:** `english` (`convaiinnovations/laya`) and `typed-decisions` (`convaiinnovations/laya-typed-decisions`) preloaded directly into ROCm GPU VRAM.
- **Latency & Footprint:**
  - Forward-pass inference latency: **~30–65 ms** per multi-question decision pass.
  - VRAM footprint: ~1.2 GiB (fits comfortably inside the Strix Halo shared memory headroom alongside Gemma and FLUX).
  - Resource allocation: Requests `1 CPU` / `4 GiB RAM`, Limits `4 CPU` / `6 GiB RAM`.
- **API Surface (`/v1/systemone` wire protocol):**
  - `GET /health`: Reports model load state and active execution device (`device: cuda`).
  - `POST /v1/systemone`: Evaluates decisions with `noul` (yes/no probability), `choice` (multiple-choice classification), and `score` (ordinal rubric scale).
  - `POST /v1/systemone/batch`: Batch evaluation over multiple states.
- **Network Endpoints:**
  - Jev Wire Protocol (`/v1/systemone`):
    - Cluster Internal: `http://laya-service.llm:8000`
    - NodePort Endpoint: `http://192.168.2.7:30800`
    - External Ingress: `https://laya.ddellspe.dev`
  - Model Context Protocol (MCP Streamable HTTP on port `8005`):
    - Cluster Internal: `http://laya-service.llm:8005/mcp`
    - NodePort Endpoint: `http://192.168.2.7:30805/mcp`
    - External Ingress: `https://laya.ddellspe.dev/mcp`
    - **Open-WebUI Tool Integration**: Registered as an external tool server (`id: laya`, type: `mcp`) exposing 8 native decision tools: `laya_status`, `laya_decide`, `laya_predict`, `laya_predict_batch`, `laya_preset` (guard, email, triage, etc.), `laya_shortlist`, `laya_route`, and `laya_route_batch`.

#### Combined Active Footprint
- **Total Unified VRAM Utilization:** Gemma 26B (~60 GiB) + FLUX.1-schnell (~31.4 GiB) + Laya (~1.2 GiB) = ~92.6 GiB total (~75% of Strix Halo unified memory pool).
- **Headroom:** Leaves ~30 GiB of headroom for the OS kernel, page caches, build tasks (DinD ARC runners), and system daemons (`node-exporter`, `caretta` eBPF).

### Deployment Strategy
- All LLM deployment manifests use `strategy.type: Recreate` so that updates to an existing deployment terminate the old pod before spinning up the new one, preventing concurrent GPU memory contention during rollouts.

### LiteLLM Router Dynamic Health Checks & Routing
- The LiteLLM Router routes conversational LLM traffic to:
  - `google/gemma-4-26B-A4B-it` via `hosted_vllm` (`http://llm-gemma26b-service.llm:8000/v1`)
- Supports native reasoning and function calling (`supports_reasoning: true`, `supports_function_calling: true`).
- LiteLLM dynamically probes backend `/health` endpoints and marks unavailable backends without dropping in-flight requests.

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
kubectl apply -k llm/llm-gemma/
kubectl apply -k llm/flux/
kubectl apply -k llm/laya/
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
Zot natively hosts both **container images** (Docker/OCI) and **Helm charts** (OCI artifacts), backed by a 100Gi `storage-warm` volume on the network-attached MergerFS HDD array (`margarita`).
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
- **Application (`buyoutyourcoach/app`)**: Next.js 16 standalone server running `registry.ddellspe.dev/buyoutyourcoach:latest` pinned to worker node `well`. Backed by a 5Gi `storage-hot` persistent volume mounted at `/app/data` for persistence and cache storage. Configured with database environment variables pointing to internal PostgreSQL.
- **Database (`buyoutyourcoach/postgres`)**: PostgreSQL 17 StatefulSet pinned to worker node `well`, backed by a 10Gi `storage-hot` volume on fast NVMe with health probes and automated initialization.

- **Internal Validation Ingress (`byc.ddellspe.dev`)**: Protected by the cluster wildcard Let's Encrypt certificate (`ddellspe-tls`) for testing and validation within the internal network.
- **Public Ingress (`buyoutyourcoach.com`)**: Configured with Traefik's automated Let's Encrypt ACME resolver (`leresolver`).
- **Continuous Deployment via Keel**: Annotated with `keel.sh/policy: "force"` and `keel.sh/pollSchedule: "@every 5m"`. Keel automatically polls `registry.ddellspe.dev`, detects when a new image digest is pushed to `:latest`, and triggers a rolling restart.

### 8. Keel Automated Image Deployment (`dev-infra/keel`)

**Keel** runs as a lightweight controller in the `dev-infra` namespace pinned to node `distiller`. It continuously monitors OCI/Docker image registries and automatically performs rolling updates on Kubernetes workloads whenever new images or updated tag digests are published.

#### Enabling Keel on Any Workload
Add annotations to the Deployment, StatefulSet, or DaemonSet:
```yaml
metadata:
  annotations:
    keel.sh/policy: "force"            # Updates workload when digest changes for the same tag (:latest)
    keel.sh/trigger: "poll"            # Uses background registry polling
    keel.sh/pollSchedule: "@every 5m"  # Polling interval (e.g. @every 1m, @every 5m, @every 10m)
    keel.sh/match-tag: "true"          # Ensures tag matches before updating
```

#### Checking Keel Status & Logs
```bash
# View Keel logs
kubectl logs -n dev-infra -l app.kubernetes.io/name=keel -f

# Check update history / change cause on a deployment
kubectl get deployment buyoutyourcoach -n buyoutyourcoach -o jsonpath='{.metadata.annotations.kubernetes\.io/change-cause}'
```

## 3-Tier Storage Architecture (`infra/storage`)

The cluster utilizes a 3-tier storage architecture designed to maximize performance, capacity, and hardware longevity:

| Tier | StorageClass | Provisioner | Backing Hardware | Characteristics | Workloads |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **HOT** | `storage-hot` | `rancher.io/local-path` | `well` NVMe (`/dev/nvme0n1p2`) | High IOPS, sub-millisecond latency, node-pinned (`WaitForFirstConsumer`) | PostgreSQL 17 (`buyoutyourcoach`), Open-WebUI SQLite (`llm`), VictoriaMetrics (`caretta-vm`), Prometheus TSDB (`monitoring`) |
| **WARM** | `storage-warm` | `nfs-subdir-external-provisioner` | `margarita` MergerFS HDD Array (`192.168.2.4:/mnt/storage/k8s`) | 220 TB high capacity, `ReadWriteMany` (RWX), `archiveOnDelete: true` | Zot OCI Registry (`dev-infra`), Grafana dashboards/db (`monitoring`) |
| **COLD** | `storage-cold` | `rancher.io/local-path` | Pi nodes (`coupe`, `rocks`, `highball`) MicroSD | Low power, lightweight, read-heavy (`WaitForFirstConsumer`) | Configs, read-only tasks; protects SD cards from database write-wear |

### Deploying Storage Infrastructure
```bash
kubectl apply -k infra/
```

## Managing Kubernetes Secrets


Secrets (API tokens, TLS certificates, credentials) are stored securely in the cluster and should never be committed to Git in plaintext.

### 1. Creating or Updating Secrets via `kubectl`

Use the idempotent `kubectl create ... --dry-run=client -o yaml | kubectl apply -f -` pattern to create or update secrets without erroring if they already exist:

#### HuggingFace Token (`hf-token-secret`)
Used by gated LLM model deployments:
```bash
kubectl create secret generic hf-token-secret \
  --namespace=llm \
  --from-literal=token="hf_YourHuggingFaceTokenHere" \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### LiteLLM Master Key (`llm-router-key`)
Stores the administrator master key for LiteLLM and Open-WebUI:
```bash
MASTER_KEY="sk-$(openssl rand -hex 32)"
kubectl create secret generic llm-router-key \
  --namespace=llm \
  --from-literal=master-key="$MASTER_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### LiteLLM PostgreSQL Secret (`litellm-db-secret`)
Stores credentials and connection string for LiteLLM's dedicated database:
```bash
DB_PASSWORD="$(openssl rand -hex 16)"
kubectl create secret generic litellm-db-secret \
  --namespace=llm \
  --from-literal=password="$DB_PASSWORD" \
  --from-literal=database-url="postgresql://litellm:${DB_PASSWORD}@litellm-postgres-service.llm.svc.cluster.local:5432/litellm" \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Traefik Auto-Auth Middleware (`llm-auto-auth`)
Injects the master key for internal `.dev` domains on API routes (`/v1/*`) via `llm-router-api-ingress` so no API key is needed when querying `llm.ddellspe.dev`, while preserving client JWTs and headers for the UI and onboarding flows on `llm-router-ingress`:
```bash
MASTER_KEY=$(kubectl get secret llm-router-key -n llm -o jsonpath='{.data.master-key}' | base64 -d)
sed "s/<LITELLM_MASTER_KEY>/$MASTER_KEY/" llm/llm-router/middleware.yaml.example | kubectl apply -f -
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
