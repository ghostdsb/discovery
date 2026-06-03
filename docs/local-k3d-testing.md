# Local Cluster Integration: Testing with k3d

This guide walks you through setting up a **live local Kubernetes cluster** using **k3d**, deploying a sample game server pod, and configuring the Discovery Service Registry to stream events and resolve routes dynamically using the native Kubernetes Watch API.

---

## 🛠️ Step-by-Step Local k3d Tutorial

### Step 1: Install k3d and Docker
Make sure Docker Desktop or Docker Engine is running on your host machine. Install the Kubernetes CLI (`kubectl`) and `k3d`:
```bash
# macOS
brew install k3d kubernetes-cli

# Linux
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.4.6 bash
```

---

### Step 2: Spin Up the k3d Cluster
We provide an automated setup script `k3d_setup.sh` in the project root. Run it to provision a local cluster:
```bash
chmod +x k3d_setup.sh
./k3d_setup.sh
```
*Once finished, k3d will output:*
`Setup complete! Cluster discovery-cluster is ready.`

Verify that your local kubectl CLI context is successfully pointed to the new k3d cluster:
```bash
kubectl config current-context
# Expected output: k3d-discovery-cluster

# Ensure nodes are ready
kubectl get nodes
```

---

### Step 3: Configure Discovery to Cluster Mode
Update your local Discovery configuration inside [config/dev.exs](file:///Users/ghostdsb/Documents/discovery/config/dev.exs) to use the local kubeconfig context:
```elixir
config :discovery,
  # Switch connection_method from :stub to :kube_config
  connection_method: :kube_config,
  namespace: "discovery"
```

---

### Step 4: Register the Application
Start the Discovery server:
```bash
mix phx.server
```
On startup, Discovery will dynamically connect to the local k3d cluster using your local `~/.kube/config` and stream K8s API events:
`[info] K8 connection success (Local Kubeconfig)`
`[info] Watcher running in cluster mode (connecting to K8s Watch API)`

Open a new terminal window and register a new app boundary named `chess-server`:
```bash
curl -X POST "http://localhost:4000/api/app" \
  -H "Content-Type: application/json" \
  -d '{"app_name": "chess-server"}'
```

---

### Step 5: Deploy a Live Game Pod using kubectl
Since Discovery is now a lean Runtime Registry (and no longer generates manifests or does GitOps commits), you deploy game pods directly using `kubectl`. 

Create a manifest file `game-pod.yaml` on your machine:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chess-server-v1
  namespace: discovery
  labels:
    app: chess-server # Must match the registered app_name
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chess-server
  template:
    metadata:
      labels:
        app: chess-server
    spec:
      containers:
        - name: game-runtime
          image: nginx:alpine # Replace with your custom game server image
          ports:
            - containerPort: 80
```

Apply this manifest directly to your local cluster:
```bash
kubectl apply -f game-pod.yaml
```

---

### Step 6: Verify Watcher Dynamic Allocation
Watch your Discovery server terminal window. The exact millisecond the pod status transitions to `Running` and passes its cluster readiness checks, the Watcher receives the K8s API event stream, processes the metadata, and caches it:
`[info] Watch Event [INITIAL]: Registering active route for app chess-server on pod chess-server-v1-...`

Query Discovery's allocation API:
```bash
curl -X GET "http://localhost:4000/api/endpoint?app_name=chess-server"
```

#### 📥 Expected JSON Response:
```json
{
  "endpoint": "chess-server.example.com/chess-server-v1-..."
}
```
*Note: Discovery dynamically resolves the actual pod IP and host from the cluster in real-time, completely bypassing terminating pods!*

---

### Step 7: Simulate a Rolling Upgrade Draining Flow
To see how session draining works, update the image tag in `game-pod.yaml` (e.g. change image to `nginx:latest`) or run a rolling update:
```bash
kubectl set image deployment/chess-server-v1 game-runtime=nginx:latest --namespace=discovery
```

#### 📦 What Happens Behind the Scenes:
1. Kubernetes spins up the new replica pod.
2. The old pod enters a `Terminating` state, receiving a `SIGTERM` signal.
3. K8s immediately strips the terminating pod from active service endpoints.
4. Discovery's K8s Watcher receives the `MODIFIED` event showing a `deletionTimestamp` on the old pod and immediately evicts it from the cache.
5. Once the new pod is fully healthy, the Watcher detects it, compares timestamps, and promotes the new pod IP as the primary endpoint.
6. Queries to `/api/endpoint` resolve the new pod URL instantly, while existing players on the old pod continue their WebSocket game loops uninterrupted!
