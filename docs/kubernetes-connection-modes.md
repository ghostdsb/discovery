# Kubernetes Connection Modes & Local k3d Setup Guide

This guide provides a comprehensive, step-by-step walkthrough for configuring and running **Discovery** in its various deployment modes, setting up a local Kubernetes sandbox using **k3d**, and managing resources via template files.

---

## 🛠️ Kubernetes Connection Modes

Discovery can communicate with Kubernetes in three distinct modes, configured via the `connection_method` key in `config/config.exs` or `config/dev.exs`.

| Connection Mode | Target Environment | Infrastructure Dependency | Description |
| :--- | :--- | :--- | :--- |
| **`:stub`** | Local Machine | **None** (Offline) | Mock sandbox mode. Does not require a K8s cluster or kubeconfig. Perfect for rapid local development and frontend debugging. |
| **`:kube_config`** | Local Development | Local/Remote K8s Cluster | Connects to an external cluster (e.g. k3d, minikube, EKS, GKE) by loading context from the default local `~/.kube/config` file. |
| **`:service_account`**| Production / Staging | Live Pod (In-Cluster) | Authenticates seamlessly using the local Service Account tokens automatically mounted inside the Pod at runtime. |

---

### 1. 📴 `:stub` (Local Sandbox Mode)

This mode runs **completely offline**. All cluster operations are mocked, and deployment metadata is loaded from local filesystem directories.

#### ⚙️ Configuration Setup
In `config/dev.exs`, set:
```elixir
config :discovery,
  connection_method: :stub,
  namespace: "discovery"
```

#### 🚀 How to Run & Use
1. **Initialize Assets & Compile**:
   ```bash
   mix setup
   mix assets.deploy
   ```
2. **Start Dev Server**:
   ```bash
   mix phx.server
   # or run with interactive Elixir shell
   iex -S mix phx.server
   ```
3. **Trigger Sandbox Deployment**:
   Run a mock deploy build via Curl (creates local folders under `data/discovery/`):
   ```bash
   curl -X POST "http://localhost:4000/api/ci/deploy" \
     -H "Content-Type: application/json" \
     -d '{
       "app_name": "chess-game",
       "image": "discovery/chess-server:v1.0.0",
       "environment": "production",
       "config_ref": {
         "app_host": "chess.local",
         "app_target_port": 80,
         "app_container_port": 4000
       },
       "idempotency_key": "sandbox-key-1"
     }'
   ```
4. **Fetch Latest Routing Endpoint**:
   ```bash
   curl -X GET "http://localhost:4000/api/endpoint?app_name=chess-game"
   ```
   *Expected Response:*
   ```json
   {
     "endpoint": "chess.local/b4f0a3a8"
   }
   ```
5. **UI Dashboard**: Open `http://localhost:4000` to view active mock deployments in the **Bridge Dashboard**.

---

### 2. 💻 `:kube_config` (Local Cluster Mode)

Used to connect to an external/local Kubernetes cluster (like k3d or minikube) from your local host machine.

#### ⚙️ Configuration Setup
In `config/dev.exs`, set:
```elixir
config :discovery,
  connection_method: :kube_config,
  namespace: "discovery"
```

#### 🚀 How to Run & Use
1. **Create Namespace** (if not already present):
   ```bash
   kubectl create namespace discovery
   ```
2. **Activate Cluster Context**:
   Verify that your kubectl context is pointing to your development cluster:
   ```bash
   kubectl config current-context
   # For k3d:
   kubectl config use-context k3d-discovery-cluster
   ```
3. **Start Dev Server**:
   ```bash
   mix phx.server
   ```
   *Note: On boot, Discovery will output connection logs:*
   `[info] K8 connection success (Local Kubeconfig)`

---

### 3. ☸️ `:service_account` (In-Cluster Mode)

This is the standard mode for **Production/Staging** deployments inside a live Kubernetes cluster.

#### ⚙️ Configuration Setup
In `config/prod.exs` or `config/runtime.exs`:
```elixir
config :discovery,
  connection_method: :service_account,
  namespace: System.get_env("DISCOVERY_NAMESPACE", "discovery"),
  service_account: System.get_env("DISCOVERY_SA", "discovery-sa")
```

#### 🚀 How to Deploy Discovery to the Cluster
1. **Create service account and roles**:
   Create a manifest `rbac.yml` to grant Discovery permission to perform CRUD operations on Deployments, Services, ConfigMaps, and Ingresses:
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: discovery-sa
     namespace: discovery
   ---
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRole
   metadata:
     name: discovery-role
   rules:
     - apiGroups: ["", "apps", "networking.k8s.io"]
       resources: ["deployments", "services", "configmaps", "ingresses", "namespaces", "pods"]
       verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
   ---
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRoleBinding
   metadata:
     name: discovery-role-binding
   subjects:
     - kind: ServiceAccount
       name: discovery-sa
       namespace: discovery
   roleRef:
     kind: ClusterRole
     name: discovery-role
     apiGroup: rbac.authorization.k8s.io
   ```
   Apply it:
   ```bash
   kubectl apply -f rbac.yml
   ```
2. **Deploy Discovery**:
   Ensure your Discovery pod spec specifies the service account name:
   ```yaml
   spec:
     serviceAccountName: discovery-sa
   ```

---

## 🐳 Starting a Local k3d Cluster

**k3d** runs a multi-node, highly-scalable Kubernetes cluster inside Docker containers. We provide an automated installation script `k3d_setup.sh` in the project root.

> [!NOTE]
> Under the hood, this script configures a private local docker registry, disables standard Traefik, installs **Ingress-Nginx** as the router, and provisions **ArgoCD** for CD pipelines.

### 📋 Prerequisites
Install Docker and k3d on your host machine:
```bash
# macOS
brew install k3d kubernetes-cli docker

# Ubuntu/Debian
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.4.6 bash
```

### 🚀 Step-by-Step Cluster Setup
1. **Ensure Docker is running**:
   Make sure your Docker Desktop or engine is booted.
2. **Execute Setup Script**:
   ```bash
   bash k3d_setup.sh
   ```
3. **Verify Cluster State**:
   Once the script displays `Setup complete!`, run:
   ```bash
   kubectl get nodes
   ```
   *Expected Output:*
   ```text
   NAME                              STATUS   ROLES                  AGE   VERSION
   k3d-discovery-cluster-server-0    Ready    control-plane,master   1m    v1.24.4+k3s1
   ```
4. **Point Ingress-Nginx Load Balancer**:
   The load balancer is mapped to port `8080` (HTTP) and `8443` (HTTPS) on your localhost. You can map domains (e.g. `chess.local`) to `127.0.0.1` inside your `/etc/hosts` file:
   ```text
   127.0.0.1 chess.local
   ```
   Then you can access your games locally via: `http://chess.local:8080/b4f0a3a8`

---

## 📄 Managing Configuration Manifests & Templates

Discovery uses standard Kubernetes raw templates located in `priv/templates/` to dynamically generate configs when CI or GitOps deploys take place.

The following templates exist under [priv/templates/](file:///Users/ghostdsb/Documents/discovery/priv/templates/):

| Template | Purpose | Key Variables Rendered |
| :--- | :--- | :--- |
| **`namespace.yml`** | Configures namespace boundaries. | `namespace` |
| **`configmap.yml`** | Holds environment-specific configs. | `app_name`, `uid`, `env_vars` |
| **`deploy.yml`** | The core pod container spec. | `app_name`, `uid`, `image`, `replicas`, `cpu/memory requests` |
| **`service.yml`** | Connects internal pod networks. | `app_name`, `uid`, `port` |
| **`ingress.yml`** | Maps traffic from host domain to service. | `app_name`, `host`, `path`, `serviceName` |

### 🛠️ How to Customize Templates
If you want to inject custom properties (e.g., node selectors, volumes, or health check probes):
1. **Modify `deploy.yml`**:
   Add environment variables, resource limits, or readiness/liveness probes directly into [priv/templates/deploy.yml](file:///Users/ghostdsb/Documents/discovery/priv/templates/deploy.yml).
2. **Modify `ingress.yml`**:
   Update annotation rewrites or custom TLS keys inside [priv/templates/ingress.yml](file:///Users/ghostdsb/Documents/discovery/priv/templates/ingress.yml).

For example, to configure health check probes in [deploy.yml](file:///Users/ghostdsb/Documents/discovery/priv/templates/deploy.yml):
```yaml
          readinessProbe:
            httpGet:
              path: /health
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
```
This change will be dynamically compiled and rendered on all subsequent deployments, ensuring zero-downtime health gates out-of-the-box!
