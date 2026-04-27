# Production Deployment Guide for Discovery

To make Discovery production-ready as a Jenkins alternative for GitOps, follow these steps:

## 1. Security Configuration

### API Token
Ensure you set a strong `API_TOKEN` environment variable. This token must be passed in the `x-api-token` header for all CI deployment requests.

### CORS Origins
Restrict CORS origins in your production environment by setting the `CORS_ORIGINS` environment variable (comma-separated list of allowed domains).

## 2. Kubernetes Integration

### Service Account
Discovery needs a Service Account with permissions to manage Deployments, Services, ConfigMaps, and Ingresses in its namespace (and other namespaces if configured).

Example ClusterRole:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: discovery-manager
rules:
- apiGroups: ["", "apps", "networking.k8s.io"]
  resources: ["deployments", "services", "configmaps", "ingresses", "namespaces"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

### Git Access
Discovery needs access to your GitOps repository. You can use a GitHub Personal Access Token (PAT) via the `GITHUB_REPO_TOKEN` environment variable.

## 3. GitOps Repository Structure

Discovery supports two main layouts:
- `env_first`: `{env}/{app}/{deployment-id}/...` (Default for CI flow)
- `apps_first`: `apps/{app}/{deployment-id}/...`

Ensure your GitOps repository is initialized and Discovery has write access to it.

## 4. Monitoring & Logs

Discovery uses Elixir's Logger. In production, ensure logs are forwarded to a centralized logging system (e.g., EFK stack, Datadog, CloudWatch).

The internal state is cached in ETS tables (`:metadatadb`, `:idempotencydb`). Note that these are ephemeral and will be cleared on restart. Discovery reconciles state by polling Kubernetes on startup.

## 5. CI Integration

Use the provided `.github/workflows/deploy-template.yml` as a starting point for your application repositories. 

Key API endpoints for CI:
- `POST /api/ci/deploy`: Trigger a new deployment.
- `GET /api/ci/status?deployment_name=...`: Check deployment status.
