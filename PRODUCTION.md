# Production Deployment Guide for Discovery

This guide details how to deploy **Discovery** in a production environment as a high-speed dynamic service directory and routing allocator.

---

## 🔒 1. Security Configuration

### API Token
For actions that alter registry listings (e.g. creating/deleting tracked apps via HTTP), secure the endpoints by specifying a strong `API_TOKEN` environment variable. Clients must include this token via the `x-api-token` header:
- Header: `x-api-token: <YOUR_SECURE_API_TOKEN>`

### CORS Origins
Restrict CORS origins in your production environment by setting the `CORS_ORIGINS` environment variable (comma-separated list of allowed domains). This is handled automatically by the endpoint routers to prevent cross-origin scripting issues.

---

## ☸️ 2. Kubernetes RBAC Configuration

To monitor pods in real-time, Discovery must run in **In-Cluster Mode** (`connection_method: :service_account`). The container's default ServiceAccount must be assigned sufficient RBAC permissions to `get`, `list`, and `watch` pods within the target namespace (e.g., `discovery`).

Apply the following RBAC manifest in production:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: discovery-service-account
  namespace: discovery
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: discovery-pod-watcher-role
  namespace: discovery
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: discovery-watcher-binding
  namespace: discovery
subjects:
- kind: ServiceAccount
  name: discovery-service-account
  namespace: discovery
roleRef:
  kind: Role
  name: discovery-pod-watcher-role
  apiGroup: rbac.authorization.k8s.io
```

*Ensure your Discovery deployment manifest references `serviceAccountName: discovery-service-account`.*

---

## ⚙️ 3. Environment Variables Config

Configure your production deployment with the following environment variables:

| Variable | Description | Example |
|---|---|---|
| `PORT` | HTTP Port for the Phoenix web server | `4000` |
| `API_TOKEN` | Auth token for base registry API routes | `super-secret-production-token-123` |
| `BASE_URL` | Base URL of Discovery for dashboard references | `http://discovery.mycompany.internal` |
| `KUBERNETES_SERVICE_HOST` | Automatically set by K8s in-cluster, overridden if needed | `10.96.0.1` |
| `KUBERNETES_SERVICE_PORT_HTTPS` | Automatically set by K8s in-cluster, overridden if needed | `443` |

---

## 📊 4. Monitoring & High Availability

- **Stateless Lifecycle**: Discovery caches all pod registry details in an ephemeral, high-concurrency memory cache (`:metadatadb` ETS table). If the Discovery container restarts, it automatically re-syncs and repopulates the ETS database from the Kubernetes API during bootstrap.
- **Health Checks**: Configure Kubernetes probes to monitor the health of Discovery:
  - **Liveness Probe**: `GET /ping` on port `4000` (responds with `pong`).
  - **Readiness Probe**: `GET /ping` on port `4000`.
- **Logs**: Discovery outputs structured JSON console logs. Route stdout to a centralized aggregator (e.g., Fluentbit, Loki, Datadog) to track client allocation events and replica changes.
