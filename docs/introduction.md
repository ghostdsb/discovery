# Introduction to Discovery

Welcome to **Discovery**, a powerful, developer-friendly orchestration platform built on top of Kubernetes designed specifically for hosting, scaling, and managing **real-time, stateful servers** with **zero downtime deployments**.

Discovery is a lightweight, GitOps-centric CD controller that serves as a highly specialized alternative to Jenkins or other generic CI/CD engines.

---

## The Problem: Deploying Stateful Servers

Standard web applications are typically **stateless**. When you deploy a new version of an API server:
1. A rolling deployment starts new containers.
2. The load balancer begins directing new HTTP requests to the new pods.
3. The old containers are terminated once active connections finish.

This works perfectly because each HTTP request is independent, short-lived, and transaction-based.

However, real-time servers (such as **game-servers, chat rooms, collaborative documents, or database connection poolers like Supavisor**) are **stateful**:
* **Persistent WebSockets**: Clients maintain open, long-lived bidirectional connections (WebSocket, TCP/UDP).
* **In-Memory Cache**: Game state, player coordinates, and session states are held directly in-memory to meet extreme latency and speed requirements.
* **Continuous Background Calculations**: Game loops, AI simulation ticks, and timers are actively executing in background threads even without active user interactions.

If you trigger a standard rolling deployment on a stateful application:
1. Kubernetes terminates the old pods immediately.
2. In-memory states are purged, causing active game sessions or chats to disconnect and fail.
3. A massive reconnection spike is triggered as thousands of clients try to reconnect, overloading your database and infrastructure.

### Why not just use Redis or Postgres for state?
While databases and key-value stores like Redis are great for persistent user data, they cannot easily store ephemeral, hyper-fast, tick-by-tick real-time states (e.g. 60Hz physics frames in multiplayer games). Furthermore, disconnecting active clients ruins the user experience, regardless of whether states are cached.

---

## The Discovery Solution: "Sticky-Session" Upgrades

Discovery solves this problem by serving as an intelligent control plane above Kubernetes. It orchestrates deployments using a **dual-action, non-terminating upgrade strategy**.

Instead of deleting old pods during an upgrade, Discovery **deploys the new version alongside the old version**, keeping both alive.

```
[ New Client Requests ] ──> [ Discovery API ] ──> Returns Server V2 (Latest)
                                   │
                                   ├──> Active Client A ──> Connected to Server V1 (Old)
                                   └──> Active Client B ──> Connected to Server V2 (Latest)
```

1. **Side-by-Side Deployments**: When you trigger a deployment (e.g. upgrade from `v1` to `v2`), Discovery spins up `v2` pods as a separate deployment with their own dedicated Services and routes.
2. **Routing Redirection**: 
   * When an existing client communicates with `v1`, their active WebSocket connection remains completely uninterrupted.
   * When a *new* client requests a connection, Discovery redirects them to the new `v2` deployment.
3. **Graceful Termination**: Older deployments are only purged after all active client connections have naturally finished or after they have reached a configurable idle timeout (meaning they are safely classified as "zombie" deployments).

This ensures **zero-downtime upgrades** for active real-time users. Your players never experience disconnects, and your servers scale smoothly.
