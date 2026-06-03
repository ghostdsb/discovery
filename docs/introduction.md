# Introduction to Discovery

Welcome to **Discovery**, a powerful, developer-friendly **High-Speed Kubernetes Runtime Service Directory & Registry** designed specifically for session-based multiplayer game servers and long-lived stateful application pods (e.g. WebSockets, database connection poolers like Supavisor).

Discovery acts as a sub-millisecond route allocator, letting you preserve active player sessions completely uninterrupted during rolling build updates.

---

## The Problem: Deploying Stateful Servers

Standard web applications are typically **stateless**. When you deploy a new version of a stateless API:
1. A rolling deployment starts new containers.
2. The load balancer begins directing new HTTP requests to the new pods.
3. The old containers are terminated immediately.

This works perfectly because each HTTP request is independent, short-lived, and transaction-based.

However, real-time servers (such as **game-servers, chat rooms, collaborative documents, or database connection poolers**) are **stateful**:
* **Persistent WebSockets**: Clients maintain open, long-lived bidirectional connections (WebSocket, TCP/UDP).
* **In-Memory Cache**: Game state, player coordinates, and active match frames are held directly in-memory to meet extreme latency and speed requirements.
* **Continuous Background Calculations**: Game loops, background ticks, and timers are actively executing in background threads even without client interactions.

If you trigger a standard rolling deployment on a stateful application:
1. Kubernetes terminates the old pods immediately.
2. In-memory states are purged, causing active game sessions to disconnect and fail.
3. A massive reconnection spike is triggered as thousands of clients try to reconnect, overloading your database and infrastructure.

---

## The Discovery Solution: "Sticky-Session" Allocations

Discovery solves this problem by separating the **deployment plane** from the **routing plane**. 

Instead of writing complex custom deployment tools, Discovery delegates the deployment rollout and connection draining entirely to **native Kubernetes rolling update primitives**:
- New pods surge immediately during updates (`maxSurge: 100%`, `maxUnavailable: 0%`).
- Old pods receive a `SIGTERM` and enter a `Terminating` state, but K8s keeps them alive for up to 40 minutes (`terminationGracePeriodSeconds: 2400`) to let active matches finish naturally over their existing WebSocket connections.
- The K8s network plane automatically removes `Terminating` pods from active service Endpoints, ensuring no *new* connections hit them.

### Discovery's Role
Discovery acts as a **super-fast dynamic registry** that sits in front of the cluster:
1. It maintains an open streaming pipe with the K8s API server using the **K8s Watch API**.
2. It dynamically reads pod events, completely evicting any pod that has a `deletionTimestamp` (which indicates it is in the 40-minute draining phase).
3. It maintains the IP/host details of the **newest, fully healthy** pod fleet inside an in-memory, highly concurrent ETS table `:metadatadb`.
4. When a game client starts up, it hits Discovery (`GET /api/endpoint?app_name=chess`). Discovery resolves the target URL in **microseconds**, bypassing draining pods and immediately connecting the new client to the freshest fleet!

This guarantees **zero-downtime stateful updates** with absolute minimum overhead!

To get started, follow our **[Getting Started Guide](getting-started.md)** or read through the complete **[Runtime Service Directory Guide](service-directory-guide.md)**.
