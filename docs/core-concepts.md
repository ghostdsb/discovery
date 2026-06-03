# Core Concepts

This section covers the core architectural building blocks, models, and operational theories that drive the Discovery Service Registry.

---

## 1. Redirect-on-Establishment Routing Flow

Unlike standard HTTP applications that proxy all user traffic continuously through a central API gateway (which adds routing latency and increases points of failure), Discovery uses a **Redirect-on-Establishment** design pattern. This is optimal for low-latency, real-time applications like multiplayer games.

```text
┌──────────┐            1. GET /api/endpoint?app_name=chess         ┌───────────┐
│  Client  │───────────────────────────────────────────────────────>│ Discovery │
│          │<───────────────────────────────────────────────────────│ Registry  │
└──────────┘              2. Returns dynamic routing URL:           └───────────┘
     │                       "chess.local/build-9f8e7d"
     │
     │ 3. Direct WebSocket / TCP Connection
     └─────────────────────────────────────────────────────────────┐
                                                                   ▼
                                                            ┌───────────┐
                                                            │  Active   │
                                                            │ Game Pod  │
                                                            └───────────┘
```

1. **Endpoint Resolution**: The client makes a quick, lightweight HTTPS REST call to Discovery: `GET /api/endpoint?app_name=chess`.
2. **Microsecond Cache Read**: Discovery performs an in-memory lookup against its public `:metadatadb` ETS table and returns the connection URL of the freshest healthy pod (e.g. `chess.local/build-9f8e7d`).
3. **Direct Session Connection**: The client connects **directly** to that specific game pod IP/port or subdomain over HTTP/WebSocket.
4. **Zero Proxy Latency**: All gameplay data, state synchronizations, and ticks occur directly between the Client and the Game Pod, completely bypassing Discovery. Discovery is never a bottleneck in the active network path.

---

## 2. Infrastructure-Native Connection Draining

Discovery delegates the complex task of connection-draining and garbage collection directly to native Kubernetes lifecycle primitives, completely avoiding custom cron scripts or connection scrapers.

```text
[ Existing Active Sessions ] ────────────────────────────────────────┐
  - Player A ──> Connected to Pod v1 (Terminating)                   │
  - Player B ──> Connected to Pod v1 (Terminating)                   ▼
                                                          [ Active Surge Pod v2 ]
[ New Matchmaking Requests ]                                         │
  - Player C ──> Hits Discovery Registry ────────────────────────────┼───> Connected to Pod v2
  - Player D ──> Hits Discovery Registry ────────────────────────────┘
```

1. **Surge Rollout**: When a build deployment is triggered, Kubernetes provisions a complete duplicate fleet of new pods (`v2`) before terminating any existing ones (`maxSurge: 100%`, `maxUnavailable: 0%`).
2. **Graceful Terminating State**: The old pods (`v1`) receive a `SIGTERM` signal and transition to a `Terminating` state, but Kubernetes keeps them alive for up to 40 minutes (`terminationGracePeriodSeconds: 2400`) to let active matches finish naturally.
3. **Automatic Network Eviction**: Kubernetes automatically removes the `Terminating` pods from the active Endpoint and Service routing plane, ensuring no *new* incoming connections are ever routed to them.

---

## 3. Real-Time Event Stream Watching (K8s Watch API)

Discovery maintains an open, long-lived streaming connection with the Kubernetes control plane using the **K8s Watch API** (`/api/v1/namespaces/discovery/pods?watch=true`).

```text
┌─────────────────┐       Watch stream events       ┌─────────────────────┐
│ K8s API Server  │────────────────────────────────>│  Discovery Watcher  │
│ (Control Plane) │                                 │ (Event-Driven Sync) │
└─────────────────┘                                 └─────────────────────┘
                                                               │
                                                               │ Atomic Updates
                                                               ▼
                                                    ┌─────────────────────┐
                                                    │ :metadatadb (ETS)   │
                                                    └─────────────────────┘
```

1. **Event Push**: The Kubernetes API server pushes JSON event chunks (`ADDED`, `MODIFIED`, `DELETED`) to Discovery the exact millisecond a pod status changes.
2. **Filtering Out Draining Fleets**: The Watcher inspects pod metadata. If the pod contains a `deletionTimestamp` (indicating it is in its 40-minute session draining phase), it is immediately evicted from the cache.
3. **Timestamp Promotion**: The Watcher compares the `creationTimestamp` of all running ready pods, promoting the absolute newest version to the active client routing table.
4. **Bootstrap & Self-Healing**: If the watcher connection drops, Discovery automatically lists all active pods to re-seed the cache, fetches the latest `resourceVersion`, and instantly restarts the streaming watch pipe, guaranteeing zero state gaps.
