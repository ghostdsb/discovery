# Getting Started

This guide walks you through setting up your local machine to run and test Discovery. By the end of this guide, you will have a local Kubernetes cluster running alongside the Discovery development server, ready to receive and trigger deployments.

---

## 🏗️ 1. Setup Your Local Kubernetes Cluster

Discovery orchestrates real Kubernetes manifests. To test it locally, you need a local Kubernetes cluster. We recommend **k3d** because it runs incredibly fast inside Docker containers.

We provide a convenient script `k3d_setup.sh` that automates this entire process.

### Running the Setup Script:
1. Ensure Docker is running on your machine.
2. Ensure you have `kubectl` and `k3d` installed (e.g., `brew install k3d kubectl` on macOS).
3. Run the script:
   ```bash
   chmod +x k3d_setup.sh
   ./k3d_setup.sh
   ```

### What does this script do?
* **Creates a local registry** named `discovery-registry` running at `localhost:5001`. This allows you to push images locally without needing to authenticate with Docker Hub.
* **Provisions a K3d cluster** named `discovery-cluster` hooked up to your local registry.
* **Installs the Ingress-Nginx controller**, which Discovery uses to route WebSocket client connections dynamically to specific pods.
* **Installs ArgoCD** inside the `argocd` namespace, preparing the cluster for GitOps workflows.

---

## ⚡ 2. Start the Discovery Server

Discovery is written in Elixir using the Phoenix Framework.

### Step 1: Install Dependencies
Install Erlang/Elixir dependencies and compile them:
```bash
mix setup
```

### Step 2: Configure the Environment
Discovery uses standard environment variables for configuration. We provide a `dev.env` template. Create your local configuration:
```bash
cp dev.env .env
source .env
```

### Step 3: Run the Development Server
Launch the server inside an interactive Elixir session (`iex`):
```bash
iex -S mix phx.server
```

Once running, you can access the visual web dashboard (Bridge) by opening [http://localhost:4000](http://localhost:4000) in your browser.

---

## 🎮 3. Deploy Your First App

Let's test if everything is working by deploying an app manually using Discovery's API.

1. **Verify your kubectl context**: Ensure kubectl is pointed to the K3d cluster:
   ```bash
   kubectl config use-context k3d-discovery-cluster
   ```
2. **Trigger a deploy**: We can trigger a deployment via curl or from the dashboard. Let's make an API call to deploy a dummy game server:
   ```bash
   curl -X POST http://localhost:4000/api/app \
     -H "Content-Type: application/json" \
     -d '{
       "name": "my-game-server"
     }'
   ```
3. **Deploy a build**:
   ```bash
   curl -X POST http://localhost:4000/api/deploy-build \
     -H "Content-Type: application/json" \
     -d '{
       "app_name": "my-game-server",
       "image": "nginx:alpine"
     }'
   ```
4. **Check the cluster**: Inspect the running pods in your cluster to see the deployed server:
   ```bash
   kubectl get pods -n discovery
   ```

You are now successfully set up for local development and deployment!
