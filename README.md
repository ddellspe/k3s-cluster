# K3s Cluster Manifests & Configurations

This repository contains the complete set of Kubernetes manifests, Helm values, and configuration files deployed across the remote K3s cluster. Manifests are split into dedicated resource kinds per workload and organized with Kustomize for streamlined GitOps and cluster management.

## Directory Structure

```text
k3s-cluster/
├── kube-system/                           # Cluster-wide system configurations
│   └── coredns/                           # CoreDNS custom rules (wildcard search-domain interceptor)
│       ├── coredns-custom.yaml
│       └── kustomization.yaml
├── llm/                                   # Accelerated LLM inference & AI gateway stack (namespace: llm)
│   ├── kustomization.yaml                 # Aggregated LLM namespace kustomization
│   ├── llm-gemma/                         # Gemma 4 26B GGUF via llama.cpp (Deployment, Service)
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   ├── llm-nemotron/                      # Nemotron 3.5 Lightning 30B GGUF via llama.cpp (Deployment, Service)
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   ├── llm-qwen36/                        # Qwen 3.6 35B AWQ via vLLM (Deployment, Service)
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
| **`llm`** | Nemotron 3.5 (GGUF), Gemma 4 (GGUF), Qwen 3.6, LiteLLM Router, Open WebUI, SearXNG, Playwright | `chat.ddellspe.dev`, `llm.ddellspe.dev`, `searxng.ddellspe.dev` |
| **`monitoring`** | Prometheus Server, Grafana, Node Exporter, Caretta (eBPF Service Map) | `grafana.ddellspe.dev`, `prometheus.ddellspe.dev` |
| **`radar`** | Radar Kubernetes Dashboard | `radar.ddellspe.dev` |
| **`kube-system`** | CoreDNS custom configuration (`coredns-custom`) | Cluster-wide DNS routing |
| **`system-upgrade`**| system-upgrade-controller, auto-updater cron | Automated weekly K3s version upgrades |

## GPU Resource Management & Model Concurrency (`distiller`)

The cluster's accelerated inference models run on node **`distiller`** (AMD Strix Halo APU with 128 GB unified memory).

### Memory Footprint & Concurrency:
- **`llm-nemotron`** (Nemotron 3.5 Lightning 30B `Q8_0` GGUF): ~31.7 GiB unified VRAM
- **`llm-gemma`** (Gemma 4 26B `Q8_0` GGUF): ~26.7 GiB unified VRAM
- **Combined Dual-Model Allocation:** ~58.4 GiB (47.1% of available GPU memory pool), leaving **over 65 GiB of free GPU headroom** on `distiller`!

### Deployment Strategy
- All LLM deployment manifests use `strategy.type: Recreate` so that updates to an existing deployment terminate the old pod before spinning up the new one.

### Switching / Scaling Models
Models can be scaled dynamically:

```bash
# 1. Scale down a model
kubectl scale deployment/llm-nemotron -n llm --replicas=0

# 2. Scale up or deploy a target model
kubectl scale deployment/llm-gemma -n llm --replicas=1
# OR deploy via Kustomize:
# kubectl apply -k llm/llm-gemma/
```

### LiteLLM Router Dynamic Health Checks
The LiteLLM Router periodically probes backend `/health` endpoints (interval: 15s). When a model is scaled to `0`, LiteLLM immediately marks that backend as unavailable, preventing failed requests from hanging.

## Deployment Examples

Deploy an entire namespace using Kustomize:
```bash
kubectl apply -k llm/
kubectl apply -k monitoring/
kubectl apply -k kube-system/coredns/
```

Deploy a specific workload:
```bash
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
