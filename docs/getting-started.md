# Getting Started

This guide walks you through setting up your local machine to run, test, and develop with **Discovery** in Sandbox Mode. By the end of this guide, you will have a local service directory running, ready to register applications, monitor active routes, and answer microsecond client allocation queries.

---

## ⚡ 1. Start the Discovery Server Locally

Discovery is built using Elixir and the Phoenix Framework. Our Sandbox Mode (`connection_method: :stub`) runs completely offline with **zero cluster or Docker dependencies**, allowing you to test everything in seconds!

### Step 1: Install Dependencies
Ensure you have Elixir and Node.js installed, then install Erlang/Elixir dependencies:
```bash
mix setup
```

### Step 2: Compile Assets
Compile the TailwindCSS/Webpack frontend styles for the Bridge Dashboard:
```bash
mix assets.deploy
```

### Step 3: Run the Development Server
Launch the server:
```bash
mix phx.server
# or run inside an interactive Elixir shell
iex -S mix phx.server
```
*Discovery will boot up in sandbox mode, outputting database initialization logs:*
`[info] Watcher running in :stub sandbox mode (monitoring data/discovery/)`

Once running, you can access the visual web dashboard by opening [http://localhost:4000](http://localhost:4000) in your browser.

---

## 🎮 2. Register Your First Application

Let's register an application boundary inside Discovery's registry so that the watcher begins tracking it.

Trigger a registration call using curl:
```bash
curl -X POST "http://localhost:4000/api/app" \
  -H "Content-Type: application/json" \
  -d '{"app_name": "chess"}'
```

---

## 🚀 3. Trigger a Mock Deployment

In local Sandbox Mode, you can trigger mock deployments either by making a REST API call or by using the **Deploy** button directly inside the Bridge Dashboard UI.

Run this curl command to simulate a rolling update trigger:
```bash
curl -X POST "http://localhost:4000/api/ci/deploy" \
  -H "Content-Type: application/json" \
  -H "x-api-token: discovery-secret-token" \
  -d '{
    "app_name": "chess",
    "image": "my-registry/chess-server:sha-9f8e7d",
    "environment": "production",
    "idempotency_key": "build-9f8e7d",
    "config_ref": {
      "app_host": "chess.local",
      "app_target_port": 80,
      "app_container_port": 4000
    }
  }'
```

#### 📦 What Happens Behind the Scenes:
In local Sandbox Mode (`connection_method: :stub`), Discovery bypasses the live Kubernetes cluster and simulates a deployment by writing mock files to your local disk at:
`data/discovery/apps/chess/chess-build-9f8e7d/`

This is strictly a local sandbox simulator designed to let you test the Watcher's pod-discovery and routing logic without a Kubernetes cluster. In production, Discovery **does not** generate or write manifests; instead, it purely streams events from the live Kubernetes API server where manifests are applied directly by your CI/CD pipeline.

---

## 🔍 4. Verify & Allocate Route

Our dynamic Watcher process detects the local sandbox files, resolves the ingress endpoint from `data/discovery/chess/ingress.yml`, and updates the concurrent ETS routing cache.

Query the Discovery API to fetch the active game server URL:
```bash
curl -X GET "http://localhost:4000/api/endpoint?app_name=chess"
```

#### 📥 Expected JSON Response:
```json
{
  "endpoint": "chess.local/build-9f8e7d"
}
```

---

## 📊 5. View in Dashboard
Open `http://localhost:4000` in your web browser. You will see **`chess`** listed as healthy, showing `1` active deployment. Click on the name to view the container image, replicas, last-updated timestamp, and the dynamic router URL `chess.local/build-9f8e7d`!

---

## ☸️ What's Next?
When you are ready to transition from the sandbox to a live Kubernetes cluster, configure the cluster connection modes and set up your local k3d development cluster:
- **[Kubernetes Connection Modes & Local k3d Setup Guide](kubernetes-connection-modes.md)**
- **[Testing with Local k3d Cluster (Live Cluster Mode)](local-k3d-testing.md)**
- **[Testing with Local K8s in Docker Compose (Live Cluster Mode)](local-k3s-compose.md)**
- **[Full Service Directory & Session Draining Guide](service-directory-guide.md)**
