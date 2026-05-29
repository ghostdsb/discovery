# API Reference

This document provides a comprehensive reference for Discovery's HTTP REST APIs.

---

## 1. Client Endpoint Discovery

Clients query this endpoint to retrieve the active websocket URL path for a stateful server.

* **Endpoint**: `GET /api/endpoint`
* **Query Parameters**:
  * `app_name` (String, required): The name of the stateful application.
* **Headers**: None (CORS is open by default to support in-browser clients).

### Example Request:
```bash
curl -X GET "http://localhost:4000/api/endpoint?app_name=nightwatch"
```

### Example Response (Success):
```json
{
  "endpoint": "https://nightwatch.example.com/nightwatch-f1a8c2"
}
```

---

## 2. CI/CD Pipeline Deployment

CI/CD engines (GitHub Actions, GitLab CI, Jenkins) trigger this endpoint to spin up new stateful upgrades.

* **Endpoint**: `POST /api/ci/deploy`
* **Headers**:
  * `x-api-token` (String, required): Authenticates the CI request. Must match your Discovery configuration.
  * `Content-Type: application/json`
* **Request Body Parameters**:
  * `app_name` (String, required): Name of the application.
  * `image` (String, required): Fully qualified Docker image and tag (e.g. `discovery/my-game:sha-123ab`).
  * `environment` (String, required): Target environment (e.g. `production`, `staging`, `dev`).
  * `idempotency_key` (String, optional): A unique identifier for the build to prevent duplicate executions on network retries.
  * `config_ref` (Map, required): Configuration mapping parameters.
    * `app_host` (String, required): Base routing hostname for the Ingress controller (e.g., `game.example.com`).
    * `app_target_port` (Integer, optional): Exposed Service port. Defaults to `80`.
    * `app_container_port` (Integer, optional): Container port the process binds to. Defaults to `4000`.
    * `secret_refs` (List, optional): References to K8s secrets to inject into the containers.

### Example Request:
```bash
curl -X POST "http://localhost:4000/api/ci/deploy" \
  -H "Content-Type: application/json" \
  -H "x-api-token: YOUR_SECRET_API_TOKEN" \
  -d '{
    "app_name": "tic-tac-toe",
    "image": "discovery/tictactoe:v1.2.3",
    "environment": "production",
    "idempotency_key": "build-884920",
    "config_ref": {
      "app_host": "tictactoe.example.com",
      "app_target_port": 80,
      "app_container_port": 4000,
      "secret_refs": ["database-credentials"]
    }
  }'
```

### Example Response (Success):
```json
{
  "success": true,
  "data": {
    "app_name": "tic-tac-toe",
    "deployment_name": "tic-tac-toe-884920",
    "environment": "production",
    "image": "discovery/tictactoe:v1.2.3",
    "endpoint": "https://tictactoe.example.com/tic-tac-toe-884920",
    "git_paths": {
      "deployment": "apps/tic-tac-toe/tic-tac-toe-884920/deployment.yml",
      "configmap": "apps/tic-tac-toe/tic-tac-toe-884920/configmap.yml",
      "service": "apps/tic-tac-toe/tic-tac-toe-884920/service.yml"
    },
    "commit": {
      "commit_sha": "d6a3f1...",
      "status": "pushed"
    }
  }
}
```

---

## 3. CI/CD Deployment Status

CI/CD pipelines query this endpoint to verify if deployment manifests exist in the GitOps local cache.

* **Endpoint**: `GET /api/ci/status`
* **Query Parameters**:
  * `deployment_name` (String, required): Name of the generated deployment (e.g. `tic-tac-toe-884920`).
* **Headers**:
  * `x-api-token` (String, required): CI Authentication token.

### Example Request:
```bash
curl -X GET "http://localhost:4000/api/ci/status?deployment_name=tic-tac-toe-884920" \
  -H "x-api-token: YOUR_SECRET_API_TOKEN"
```

### Example Response:
```json
{
  "success": true,
  "data": {
    "exists": true,
    "files": {
      "deployment_yaml": true,
      "configmap_yaml": true
    },
    "paths": {
      "deployment": "apps/tic-tac-toe/tic-tac-toe-884920/deployment.yml",
      "configmap": "apps/tic-tac-toe/tic-tac-toe-884920/configmap.yml"
    }
  }
}
```

---

## 4. GitOps Manual Operations

Discovery exposes administrative endpoints to manually sync or manipulate the GitOps state.

### A. List All Apps
Retrieve a list of all stateful applications managed in the GitOps repository.
* **Endpoint**: `GET /api/gitops/apps`
* **Response**:
```json
{
  "apps": ["tic-tac-toe", "watchex", "chat-server"]
}
```

### B. Manually Trigger a Repository Sync
Forcefully push the current state of local configuration manifests to the remote GitOps repository.
* **Endpoint**: `POST /api/gitops/sync`
* **Response**:
```json
{
  "success": true,
  "data": {
    "message": "Full sync completed",
    "commit": {
      "sha": "a1b2c3d...",
      "status": "pushed"
    }
  }
}
```
