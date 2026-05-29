# Bridge: Visual Dashboard

**Bridge** is Discovery's built-in visual management dashboard. Built using **Phoenix LiveView**, it offers real-time, bidirectional reactivity, allowing you to monitor active stateful deployments, inspect cluster states, scale replicas, and inspect deployment logs directly from your browser.

Bridge is running by default on your Discovery instance at [http://localhost:4000](http://localhost:4000).

---

## 1. Features & Capabilities

* **Real-Time Visual State**: View active Kubernetes pod statuses, ingress routes, and resource usages without needing `kubectl`.
* **Zero-Configuration UI**: Automatically syncs and updates whenever deployment configurations are edited or added via GitOps CI endpoints.
* **Log Inspection**: Fetch and tail pod logs in real-time, making debugging stateful errors straightforward.
* **Manual Purging & Terminations**: Identify and delete inactive, stale, or "zombie" deployments to free up cluster resources.
* **Application Scaling**: Adjust minimum/maximum replica pools for running servers with a single slider.

---

## 2. Managing Applications

### A. Creating an Application
To provision a new stateful application:
1. Click the **"Create App"** button in the dashboard.
2. Provide a globally unique, URL-friendly application name (e.g., `chess-game`).
3. Set the initial base image registry path (e.g., `discovery/chess-server:latest`).
4. Click **"Save"**. Discovery will initialize the app namespaces, create routing points, and write the initial base template configurations to your GitOps repository.

### B. Deploying & Scaling Upgrades
When a new CI build is triggered, the dashboard animates:
* **Active Status Logs**: Shows the rollout progression (e.g., pulling images, starting containers, verifying readiness probes).
* **Side-by-Side Rollout**: You will see both the old deployment (e.g., `chess-game-v1`) and the new deployment (`chess-game-v2`) listed.
* **Connection Gauges**: Displays active websocket connections on each pod. Once the old pods drop to 0 active connections, they can be terminated gracefully.

### C. Live Log Streaming
To inspect why a stateful pod is experiencing errors:
1. Click on the active pod entry in the dashboard.
2. The log window will open and dynamically stream stdout/stderr logs directly from the Kubernetes container into your browser.
3. This is fully reactive and handles high-throughput logs using Phoenix Channels.

---

## 3. Idle "Zombie" Cleaner

Stateful servers keep running even when zero clients are connected. This can lead to resource leaks if stale builds aren't cleaned up.

Bridge exposes and integrates with Discovery's **Zombie Cleaner**:
* **Automated Cron Cleaning**: Discovery is configured to run a cleaner background task at midnight (customizable via `Discovery.Scheduler`).
* **Manual Purge**: You can view a dedicated tab in Bridge labeled "Stale Deployments". This lists pods that have had 0 connections for over 1 hour. You can click **"Purge"** to manually terminate the pods and remove the inactive ingress paths.
