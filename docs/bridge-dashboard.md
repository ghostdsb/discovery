# Bridge: Visual Dashboard

**Bridge** is Discovery's built-in visual registry management dashboard. Powered by **Phoenix LiveView**, it offers real-time, bidirectional reactivity, allowing you to monitor active stateful pod allocations, inspect connection routing endpoints, register new applications, and trigger mock sandbox deployments directly from your web browser.

Bridge is running by default on your Discovery instance at [http://localhost:4000](http://localhost:4000).

---

## 1. Features & Capabilities

* **Real-Time Registry View**: Visualizes active Kubernetes pod endpoints, images, and ingress hosts in real-time.
* **Instant Reconnect Mapping**: Inspect precisely where client traffic is being routed (e.g. `chess.local/build-9f8e7d`).
* **Clean Stateful Eviction**: Draining/terminating pods automatically vanish from the listings the exact millisecond K8s updates their status, presenting a clean representation of active routing.
* **Zero-Infrastructure Sandbox**: Click the "Deploy" button in Sandbox Mode to automatically generate mock manifests locally, letting you test routing and layouts interactively with zero K8s dependencies.

---

## 2. Managing the Registry

### A. Registering an Application
To register a stateful application boundary in the registry:
1. Click the **"Create App"** button on the homepage.
2. Provide a globally unique, URL-friendly application ID (e.g., `chess`).
3. Click **"Create"**. Discovery will add the app to the Bridge database, ready to track its pods.

---

### B. Tracking Active Allocations
Clicking on any registered app opens the **App Inspector**:
- **Allocation Log**: Shows the active pod's unique version (its serial UID or git-commit), container image tag, replicas count, and dynamic URL.
- **Dynamic Endpoint API**: Displays the REST URL clients hit to retrieve this allocation data.

---

### C. Triggering Interactive Sandbox Deploys
When running locally in **Sandbox Mode** (`connection_method: :stub`), you can test deployments interactively:
1. Click **"Deploy"** inside the App Inspector.
2. Provide a mock docker image name (e.g., `my-game:v1.2.0`).
3. Click **"Create"**.
4. Discovery immediately writes mock files to the local folder. The Watcher detects the new deployment, parses its configurations, and routes the new endpoint URL inside the dashboard.
