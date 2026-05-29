# Core Concepts

This section covers the core architectural building blocks, models, and operational theories that drive Discovery.

---

## 1. Client-Server Routing Flow

Unlike standard REST applications that proxy traffic continuously through a central API gateway (which adds latency and increases points of failure), Discovery uses a **Redirect-on-Establishment** design pattern. This is optimal for latency-sensitive applications like games.

```
┌──────────┐            1. GET /api/endpoint?app_name=mmo           ┌───────────┐
│  Client  │───────────────────────────────────────────────────────>│ Discovery │
│          │<───────────────────────────────────────────────────────│  Server   │
└──────────┘              2. Returns endpoint URL:                  └───────────┘
     │                       "https://mmo.example.com/mmo-1d9c0"
     │
     │ 3. Direct WebSocket Connection
     └─────────────────────────────────────────────────────────────┐
                                                                   ▼
                                                            ┌───────────┐
                                                            │  Active   │
                                                            │ Game Pod  │
                                                            └───────────┘
```

1. **Endpoint Resolution**: The client makes a quick HTTPS REST call to Discovery asking for the active endpoint of a stateful application (e.g. `GET /api/endpoint?app_name=mmo`).
2. **Sticky Route Assignment**: Discovery inspects its local ETS database cache for the active deployment, generates a route with a unique identifier, and returns the path (e.g., `https://mmo.example.com/mmo-1d9c0`).
3. **Direct Session Connection**: The client connects *directly* to that specific game pod using WebSockets.
4. **Independent Communication**: All gameplay, events, and data transfers happen directly between the Client and the Game Pod, completely bypassing Discovery, ensuring zero routing latency.

---

## 2. Zero-Downtime Upgrade Mechanics

When you deploy a new image tag, Discovery handles the rollout smoothly:

```
[ Active Connections ] ──────────────────────────────────────────────┐
  - Player A (WebSocket) ──> Connected to Server v1                  │
  - Player B (WebSocket) ──> Connected to Server v1                  ▼
                                                            [ Deploy Server v2 ]
[ New Requests ]                                                     │
  - Player C ──> Hits Discovery API ─────────────────────────────────┼───> Connected to Server v2
  - Player D ──> Hits Discovery API ─────────────────────────────────┘
```

1. **Deploy v2 Side-by-Side**: A new Kubernetes `Deployment` object is created (`my-app-v2`) with its own corresponding `Service` cluster IP (`my-app-v2`).
2. **Patch Ingress Rules**: Discovery updates the Ingress Controller. It adds a routing prefix path matching `/my-app-v2/*` which maps directly to the `my-app-v2` Service.
3. **API Routing Update**: Discovery's internal database updates its "Active Routing" metadata table. 
   * Subsequent client queries to `GET /api/endpoint?app_name=my-app` now return the new `/my-app-v2` route.
   * Existing connections to `/my-app-v1` are **never disconnected**. They remain connected to the old pod until the player logs off, dies, or finishes the match.
4. **Tombstone & Purge**: Discovery monitors active connections (or implements an idle lease timeout). Once the `my-app-v1` pod has 0 active connections or has expired, Discovery deletes the Kubernetes resources, cleaning up cluster resources.

---

## 3. GitOps Orchestration (Dual-Action Strategy)

Discovery functions as a GitOps-centric Continuous Delivery controller. It coordinates Kubernetes manifests with your Git repositories.

To achieve maximum deployment speed while maintaining standard Git configuration management, Discovery implements a **Dual-Action Direct Apply** strategy:

```
                  ┌───────────────┐
                  │  CI Pipeline  │
                  └───────────────┘
                          │
                          │ POST /api/ci/deploy
                          ▼
             ┌─────────────────────────┐
             │    Discovery Server     │
             └─────────────────────────┘
              /                       \
             /                         \
  1. Direct Apply                       2. Commit & Push
           /                             \
          ▼                               ▼
 ┌─────────────────┐             ┌─────────────────┐
 │   Kubernetes    │             │   GitOps Repo   │
 │     Cluster     │             │  (Source of     │
 │ (Instant Start) │             │     Truth)      │
 └─────────────────┘             └─────────────────┘
```

1. **Direct K8s Apply (Instant Execution)**:
   * Discovery dynamically generates standard Kubernetes YAML resource manifests (`Deployment`, `Service`, `ConfigMap`, `Ingress`).
   * It immediately submits these configurations to the Kubernetes API using its active K8s client.
   * This ensures your new servers start booting **instantly** without waiting for long Git sync loops or polling times.
2. **GitOps Persistence (Configuration Management)**:
   * Concurrently, Discovery clones your remote GitOps repository.
   * It writes the generated YAML manifests to the repo under the specified directory layout.
   * It commits and pushes these changes back to the remote GitOps repository.
   * This guarantees that your GitOps repository remains the absolute, up-to-date **Source of Truth** for your cluster configurations.

---

## 4. GitOps Repository Directory Layouts

Discovery supports two different structural layouts within your GitOps config repositories:

### A. Environment-First Layout (`env_first`)
This structures directories based on environments first. Ideal for larger enterprise clusters:
```
{gitops-repo}/
├── dev/
│   └── apps/
│       └── my-app/
│           ├── deployment.yml
│           └── service.yml
├── staging/
└── production/
```

### B. Application-First Layout (`apps_first`)
This structures files by application name first, with environment files inside. Ideal for smaller clusters or simple setups:
```
{gitops-repo}/
└── apps/
    └── my-app/
        ├── dev/
        │   ├── deployment.yml
        │   └── service.yml
        └── prod/
```
These layout strategies can be configured globally in your `config.exs` or customized dynamically in each CI pipeline deployment request.
