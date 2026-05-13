#!/bin/bash

# Base configuration
BASE_URL=${BASE_URL:-"http://localhost:4000"}
API_TOKEN=${API_TOKEN:-"your_api_token_here"}

echo "Using BASE_URL: $BASE_URL"

# --- Base / Ping ---
echo "GET /ping"
curl -X GET "$BASE_URL/ping"
echo -e "\n"

# --- Endpoint ---
echo "GET /api/endpoint"
curl -X GET "$BASE_URL/api/endpoint?app_name=my-app"
echo -e "\n"

# --- App Management ---
echo "GET /api/apps"
curl -X GET "$BASE_URL/api/apps"
echo -e "\n"

echo "GET /api/:app_name/deployments"
curl -X GET "$BASE_URL/api/my-app/deployments"
echo -e "\n"

echo "POST /api/app"
curl -X POST "$BASE_URL/api/app" \
     -H "Content-Type: application/json" \
     -d '{"app_name": "my-app"}'
echo -e "\n"

echo "POST /api/deploy-build"
curl -X POST "$BASE_URL/api/deploy-build" \
     -H "Content-Type: application/json" \
     -d '{
       "app_name": "my-app",
       "app_image": "my-image:latest",
       "config_map": {},
       "app_host": "my-app.com",
       "app_target_port": 4000,
       "app_container_port": 4000
     }'
echo -e "\n"

echo "DELETE /api/app"
curl -X DELETE "$BASE_URL/api/app" \
     -H "Content-Type: application/json" \
     -d '{"app_name": "my-app"}'
echo -e "\n"

echo "DELETE /api/deployment"
curl -X DELETE "$BASE_URL/api/deployment" \
     -H "Content-Type: application/json" \
     -d '{"deployment_name": "my-app-uniqueid"}'
echo -e "\n"

# --- GitOps Endpoints ---
echo "POST /api/gitops/update-image"
curl -X POST "$BASE_URL/api/gitops/update-image" \
     -H "Content-Type: application/json" \
     -d '{
       "app_name": "my-app",
       "new_tag": "v2",
       "environment": "production"
     }'
echo -e "\n"

echo "POST /api/gitops/create-app"
curl -X POST "$BASE_URL/api/gitops/create-app" \
     -H "Content-Type: application/json" \
     -d '{
       "app_name": "my-app",
       "image_name": "my-image",
       "environment": "production"
     }'
echo -e "\n"

echo "GET /api/gitops/apps"
curl -X GET "$BASE_URL/api/gitops/apps"
echo -e "\n"

echo "GET /api/gitops/image-tag"
curl -X GET "$BASE_URL/api/gitops/image-tag?app_name=my-app&environment=production"
echo -e "\n"

echo "POST /api/gitops/sync"
curl -X POST "$BASE_URL/api/gitops/sync" \
     -H "Content-Type: application/json" \
     -d '{"commit_message": "Syncing all to GitOps"}'
echo -e "\n"

echo "POST /api/gitops/sync-app"
curl -X POST "$BASE_URL/api/gitops/sync-app" \
     -H "Content-Type: application/json" \
     -d '{
       "app_name": "my-app",
       "commit_message": "Syncing my-app to GitOps"
     }'
echo -e "\n"

echo "POST /api/gitops/sync-from-discovery"
curl -X POST "$BASE_URL/api/gitops/sync-from-discovery" \
     -H "Content-Type: application/json" \
     -d '{"commit_message": "Syncing Discovery state to GitOps"}'
echo -e "\n"

echo "POST /api/gitops/sync-app-from-discovery"
curl -X POST "$BASE_URL/api/gitops/sync-app-from-discovery" \
     -H "Content-Type: application/json" \
     -d '{
       "app_name": "my-app",
       "commit_message": "Syncing my-app from Discovery to GitOps"
     }'
echo -e "\n"

# --- CI Endpoints (Require API Token) ---
echo "POST /api/ci/deploy"
curl -X POST "$BASE_URL/api/ci/deploy" \
     -H "Content-Type: application/json" \
     -H "x-api-token: $API_TOKEN" \
     -d '{
       "app_name": "my-app",
       "image": "my-image:v1",
       "environment": "production",
       "config_ref": {},
       "idempotency_key": "optional-key"
     }'
echo -e "\n"

echo "GET /api/ci/status"
curl -X GET "$BASE_URL/api/ci/status?deployment_name=my-app-uniqueid" \
     -H "x-api-token: $API_TOKEN"
echo -e "\n"
