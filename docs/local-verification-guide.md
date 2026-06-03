# 🚀 Local Verification & k3d Deployment Guide

This guide details how to verify the **Discovery Service Registry** APIs and deploy it locally inside a **k3d** Kubernetes cluster using Docker images, with zero external registry requirements.

---

## 📡 API Reference Checklist

Discovery provides highly performant API endpoints to track app domains, check real-time watcher state, and fetch live pod endpoints.

| Method | Endpoint | Description | Query / JSON Params | Auth Header (Optional) |
|:---|:---|:---|:---|:---|
| **`POST`** | `/api/app` | Add an application to the Watcher's tracking list | `{"app_name": "chess"}` | `x-api-token: <token>` |
| **`GET`** | `/api/apps` | List all applications currently tracked by the Watcher | *None* | *None* |
| **`GET`** | `/api/watcher/status` | Query active pod registration and healthy route cache state | `?app_name=chess` | *None* |
| **`GET`** | `/api/endpoint` | Fetch the freshest healthy routing endpoint for clients | `?app_name=chess` | *None* |
| **`DELETE`** | `/api/app` | Delete an app and evict its endpoints | `{"app_name": "chess"}` | `x-api-token: <token>` |

---

## 🐳 Step 1: Build & Deploy to a Local k3d Cluster

Follow these steps to package Discovery as a container, import it into k3d, and run it in cluster mode.

### 1. Build the Docker Image Locally
Run the Docker build command using the development Dockerfile:
```bash
docker build -f dev.Dockerfile -t discovery-app:latest .
```

### 2. Boot up your k3d Cluster
Ensure your local k3d cluster is active (run `./k3d_setup.sh` to provision if not already running):
```bash
k3d cluster list
# Should list: discovery-cluster
```

### 3. Load the Image into k3d Directly (No Registry Needed!)
k3d has a native `image import` command that side-loads images from your Docker daemon directly into the cluster nodes:
```bash
k3d image import discovery-app:latest -c discovery-cluster
```

### 4. Deploy the Stack to k3d
Deploy the complete Namespace, RBAC configs, Service, Ingress, and Deployment configurations:
```bash
kubectl apply -f k8s/dev-deployment.yaml
```

### 5. Verify the Pod is Running
```bash
kubectl get pods -n discovery
```
*Expected Output:*
```
NAME                             READY   STATUS    RESTARTS   AGE
discovery-app-798cf647d6-x8r7z   1/1     Running   0          10s
```

---

## 🧪 Step 2: End-to-End Live Cluster Verification

To check if the watcher is successfully streaming and registering pods dynamically in k3d:

### 1. Route local traffic
Add the following line to `/etc/hosts` to point the local ingress to your host loopback:
```hosts
127.0.0.1 discovery.localhost
```

### 2. Register `chess-server` app on the cluster
```bash
curl -X POST "http://discovery.localhost:8080/api/app" \
  -H "Content-Type: application/json" \
  -d '{"app_name": "chess-server"}'
```

### 3. Deploy a sample game server
Deploy a test pod in the `discovery` namespace:
```yaml
# Save as sample-game.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chess-server-v1
  namespace: discovery
  labels:
    app: chess-server
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
        image: nginx:alpine
        ports:
        - containerPort: 80
```
Apply the manifest:
```bash
kubectl apply -f sample-game.yaml
```

### 4. Verify Active Watcher Routing
Query the watcher status endpoint on the running pod:
```bash
curl -X GET "http://discovery.localhost:8080/api/watcher/status?app_name=chess-server"
```

The watcher will instantly stream the event from the API server and return:
```json
{
  "app_name": "chess-server",
  "tracked": true,
  "active": true,
  "details": {
    "ip": "10.42.0.12",
    "port": 80,
    "created_at": "2026-06-02T13:50:20Z",
    "version": "45293",
    "url": "chess-server.example.com/chess-server-v1-...",
    "image": "nginx:alpine",
    "replicas": 1,
    "last_updated": "2026-06-02T13:50:20Z"
  }
}
```

Dynamic route resolution is fully functional! 🎉
