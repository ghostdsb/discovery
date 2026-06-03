# Getting Started

This guide walks you through setting up **Discovery** inside a Kubernetes cluster, registering your application, and allocating client connections.

---

## ⚡ 1. How Discovery Works in a Cluster

Discovery acts as a super-fast dynamic registry. Instead of managing container lifecycle or templates itself, it connects directly to the Kubernetes API:
1. You run a standard deployment of your app in Kubernetes.
2. The **Watcher Subsystem** (`Discovery.Kubernetes.Watcher`) receives events from the K8s API in real-time.
3. It promotes the freshest healthy pod to the active routing cache.
4. Game clients query Discovery for the latest active suffix, then connect directly via Ingress.

---

## ☸️ 2. Deploy Discovery to a Cluster

For local testing, ensure your local cluster is running (such as the k3d cluster defined in `k3d_setup.sh`).

### Step 1: Build the Docker Image
Build the container image using the development Dockerfile:
```bash
docker build -f dev.Dockerfile -t discovery-app:latest .
```

### Step 2: Sideload Image (No External Registry Needed)
If using k3d, import the image:
```bash
k3d image import discovery-app:latest -c discovery-cluster
```
If using our Docker Compose k3s setup:
```bash
make k8s-redeploy
```

### Step 3: Apply the Manifests
Deploy the namespace, RBAC permissions, service, and ingress routing rules:
```bash
KUBECONFIG=data/k3s/kubeconfig.yaml kubectl apply -f k8s/dev-deployment.yaml
```
Verify the pod is running:
```bash
KUBECONFIG=data/k3s/kubeconfig.yaml kubectl get pods -n discovery
```

---

## 🎮 3. Register Your Application

To start tracking an app, register it via the REST API (or by clicking "Create App" on the visual dashboard at `http://discovery.localhost:8080`):

```bash
curl -X POST "http://discovery.localhost:8080/api/app" \
  -H "Content-Type: application/json" \
  -d '{"app_name": "wsgo-price"}'
```
*Once registered, the Watcher will automatically stream all pod changes with label `app=wsgo-price` inside the namespace.*

---

## 🚀 4. Deploy Your Application

Deploy your application manifests. Ensure your pods include:
* The label `app: <your-app-name>` matching the registered name.
* Correct port configuration.

For example, apply `wsgo-price`'s deployment:
```bash
KUBECONFIG=data/k3s/kubeconfig.yaml kubectl apply -f path/to/wsgo-price/k8s/deployment.yaml
```

Once the pods transition to `Running` and pass readiness probes, the Watcher will instantly capture them.

---

## 🔍 5. Query and Resolve Routes

### 1. Check Watcher Status
Query the Watcher status endpoint to verify it has registered the healthy pods:
```bash
curl -X GET "http://discovery.localhost:8080/api/watcher/status?app_name=wsgo-price"
```
*Response (Active!):*
```json
{
  "active": true,
  "app_name": "wsgo-price",
  "details": {
    "created_at": "2026-06-03T12:12:22Z",
    "image": "ghostdsbdocker/wsgo:0.0.8",
    "ip": "10.42.0.30",
    "port": 8000,
    "url": "wsgo-price.example.com/gj6dm"
  },
  "tracked": true
}
```

### 2. Allocate Route for Client
Query the endpoint allocation API:
```bash
curl -X GET "http://discovery.localhost:8080/api/endpoint?app_name=wsgo-price"
```
*Response:*
```json
{
  "endpoint": "wsgo-price.example.com/gj6dm"
}
```
The client can now establish a WebSocket connection directly to `ws://wsgo-price.example.com:8080/gj6dm/ws`!
