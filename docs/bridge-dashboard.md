# Bridge: Visual Dashboard

**Bridge** is Discovery's built-in visual registry management dashboard. Powered by **Phoenix LiveView**, it offers real-time, bidirectional reactivity, allowing you to monitor active stateful pod allocations, inspect connection routing endpoints, and register new applications directly from your web browser.

Bridge runs by default on your Discovery instance at [http://localhost:4000](http://localhost:4000) (or `http://discovery.localhost:8080` in local clusters).

---

## 1. Features & Capabilities

* **Real-Time Registry View**: Visualizes active Kubernetes pod endpoints, images, and ingress hosts in real-time.
* **Network Deployment Graph**: Generates a live node-graph linking the ingress router to all healthy pods in the replica set.
* **Active Route Promotion**: Automatically tags and highlights the single freshest ready pod in glowing emerald green, signifying where incoming connection allocation requests are routed.
* **Clean Stateful Eviction**: Draining/terminating pods automatically switch to `DRAINING` status and are greyed out, letting you watch connection-draining progress visually as old client sessions wind down.

---

## 2. Managing the Registry

### A. Registering an Application
To start tracking a stateful application boundary in the registry:
1. Click the **"Create App"** button on the homepage.
2. Provide the application name matching the `app` label in your Kubernetes pod manifests (e.g., `wsgo-price`).
3. Click **"Create"**. Discovery will add the app to the Bridge database, and the Watcher will automatically start streaming its pod events in real-time.

---

### B. Tracking Active Allocations
Clicking on any registered app opens the **App Inspector**:
- **Connection Integration Details**: Displays the endpoint API URL that game clients hit to fetch the latest allocation, as well as the dynamic suffix route.
- **Topology Graph**: A live visual graph representing the Ingress Router connecting directly to the running replica set. Hover or click on the pod nodes to inspect dynamic details like container IP, port, image path, resource version, and creation timestamp.
