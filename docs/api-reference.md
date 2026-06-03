# API Reference

This document provides a comprehensive API reference for the Discovery Service Registry REST endpoints.

---

## 1. Health Check
Retrieves the service health and current semantic version.

* **Endpoint**: `GET /ping`
* **Response Headers**: `Content-Type: application/json`
* **Response Body**:
```json
"pong from discovery: v0.3.0"
```

---

## 2. Client Endpoint Discovery (Allocation)
Query this endpoint to retrieve the active websocket routing URL of the freshest healthy pod.

* **Endpoint**: `GET /api/endpoint`
* **Query Parameters**:
  * `app_name` (String, required): The name of the registered stateful application (e.g. `chess`).
* **Headers**: None (CORS is open by default to support direct browser integrations).

### Example Request:
```bash
curl -X GET "http://localhost:4000/api/endpoint?app_name=chess"
```

### Example Response (Success):
```json
{
  "endpoint": "chess.local/build-9f8e7d"
}
```

---

## 3. List Registered Applications
Retrieves a list of all application boundaries currently registered for tracking.

* **Endpoint**: `GET /api/apps`

### Example Request:
```bash
curl -X GET "http://localhost:4000/api/apps"
```

### Example Response:
```json
{
  "apps": [
    {
      "app_name": "chess",
      "deployments": 1,
      "url": "http://localhost:4000/api/endpoint?app_name=chess"
    }
  ]
}
```

---

## 4. Register a New Application
Add an application name label to the directory. Discovery will begin watching the cluster namespaces for pods matching this label.

* **Endpoint**: `POST /api/app`
* **Request Headers**: `Content-Type: application/json`
* **Request Body Parameters**:
  * `app_name` (String, required): Globally unique name of the application.

### Example Request:
```bash
curl -X POST "http://localhost:4000/api/app" \
  -H "Content-Type: application/json" \
  -d '{"app_name": "sudoku"}'
```

### Example Response:
```json
{
  "app_name": "sudoku"
}
```

---

## 5. Deregister an Application
Remove an application boundary and evict all active routing paths from the registry.

* **Endpoint**: `DELETE /api/app`
* **Request Headers**: `Content-Type: application/json`
* **Request Body Parameters**:
  * `app_name` (String, required): The name of the registered application.

### Example Request:
```bash
curl -X DELETE "http://localhost:4000/api/app" \
  -H "Content-Type: application/json" \
  -d '{"app_name": "sudoku"}'
```

### Example Response:
```json
{
  "app_name": "sudoku"
}
```
