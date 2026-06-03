# Local Kubernetes via Docker Compose (k3s)

This guide walks you through running a fully functioning, lightweight **Kubernetes cluster (k3s)** directly inside **Docker Compose**. 

This is the ultimate local development setup: it requires **zero external binaries** (no k3d or minikube installations required). If you have Docker, you can run a full Kubernetes control plane with a single command!

---

## 🚀 Step-by-Step Local Compose Tutorial

### Step 1: Boot the Cluster
Make sure Docker is running on your host machine. Spin up the containers defined in the project's root `docker-compose.yaml` in background mode:
```bash
docker compose up -d
```
*Docker will pull and boot the containers, automatically writing the cluster's secure access credential file (`kubeconfig.yaml`) directly into your project workspace at `data/k3s/kubeconfig.yaml`.*

---

### Step 2: Configure kubectl to use the Compose Cluster
Tell your local `kubectl` CLI to read from the generated kubeconfig context:
```bash
export KUBECONFIG=data/k3s/kubeconfig.yaml

# Verify nodes are running
kubectl get nodes
```
*Expected Output:*
```text
NAME         STATUS   ROLES                  AGE   VERSION
k3s-server   Ready    control-plane,master   15s   v1.24.4+k3s1
```

---

### Step 3: Run the local API Proxy
Since local host applications (like Discovery) running outside of Docker need to communicate with the cluster securely, run a local **kubectl proxy**:
```bash
kubectl proxy --port=8001
```
> [!NOTE]
> This starts a lightweight HTTP proxy on `http://localhost:8001`. It handles TLS and credential headers automatically, letting local host clients talk to the K8s API server securely without certificate warnings.

---

### Step 4: Configure Discovery
Update your local dev environment config inside [config/dev.exs](file:///Users/ghostdsb/Documents/discovery/config/dev.exs) to run in cluster mode:
```elixir
config :discovery,
  connection_method: :kube_config,
  namespace: "discovery"
```

Start the Discovery server:
```bash
mix phx.server
```
*Discovery will connect to the proxy automatically on boot:*
`[info] K8 connection success (Local Kubeconfig)`
`[info] Watcher running in cluster mode (connecting to K8s Watch API)`

---

### Step 5: Test the Registry Allocation

1. **Register App**: Open a new terminal and register `chess` in the directory:
   ```bash
   curl -X POST "http://localhost:4000/api/app" \
     -H "Content-Type: application/json" \
     -d '{"app_name": "chess"}'
   ```
2. **Deploy Pod**: Create a sample deployment manifest `game.yaml`:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: chess-v1
     namespace: discovery
     labels:
       app: chess
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: chess
     template:
       metadata:
         labels:
           app: chess
       spec:
         containers:
           - name: game
             image: nginx:alpine
             ports:
               - containerPort: 80
   ```
   Apply it to the cluster:
   ```bash
   kubectl apply -f game.yaml
   ```
3. **Verify Route Resolution**: Once the pod is running, query Discovery:
   ```bash
   curl -X GET "http://localhost:4000/api/endpoint?app_name=chess"
   ```
   *Expected Response:*
   ```json
   {
     "endpoint": "chess.example.com/chess-v1-..."
   }
   ```
   *Note: The returned endpoint contains the dynamically resolved pod ID inside the live Docker Compose cluster!*

---

## 🧹 Tearing Down the Cluster
To stop and clean up all containers and network states:
```bash
docker compose down -v
```
