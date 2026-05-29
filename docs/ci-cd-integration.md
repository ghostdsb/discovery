# CI/CD Integration Guide

Discovery is designed to act as a lightweight, GitOps-centric CD controller. You can trigger and orchestrate zero-downtime stateful upgrades directly from your standard CI/CD pipelines (GitHub Actions, GitLab CI, or Jenkins).

This guide provides drop-in templates for integrating Discovery into your build workflows.

---

## 1. GitHub Actions Integration

To deploy an application from GitHub Actions:
1. Ensure your GitHub repo has secrets set up for:
   * `DISCOVERY_URL`: The HTTP endpoint of your Discovery instance (e.g. `https://discovery.example.com`).
   * `DISCOVERY_TOKEN`: The API token (configured as `api_token` in Discovery).
2. Copy this file into your application repository as `.github/workflows/deploy.yml`:

```yaml
name: Deploy Stateful Server

on:
  push:
    branches: [ main ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Source Code
        uses: actions/checkout@v4

      - name: Log in to Docker Registry
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Build and Push Container Image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          # Tags using git commit SHA
          tags: discovery/my-server:sha-${{ github.sha }}

      - name: Trigger Discovery Deployment
        run: |
          echo "Triggering Discovery CD deploy..."
          
          curl -s -X POST "${{ secrets.DISCOVERY_URL }}/api/ci/deploy" \
            -H "Content-Type: application/json" \
            -H "x-api-token: ${{ secrets.DISCOVERY_TOKEN }}" \
            -d '{
              "app_name": "my-server-app",
              "image": "discovery/my-server:sha-${{ github.sha }}",
              "environment": "production",
              "idempotency_key": "build-${{ github.sha }}",
              "config_ref": {
                "app_host": "myserver.example.com",
                "app_target_port": 80,
                "app_container_port": 4000
              }
            }' > deploy_response.json
            
          cat deploy_response.json
          
          # Verify deployment was successful
          SUCCESS=$(jq '.success' deploy_response.json)
          if [ "$SUCCESS" != "true" ]; then
            echo "❌ Deployment failed!"
            exit 1
          fi
          
          echo "✅ Deployment triggered successfully!"
```

---

## 2. GitLab CI/CD Integration

Copy this snippet into your application's `.gitlab-ci.yml` file:

```yaml
stages:
  - build
  - deploy

build_image:
  stage: build
  image: docker:stable
  services:
    - docker:dind
  script:
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
    - docker build -t "discovery/my-server:sha-$CI_COMMIT_SHORT_SHA" .
    - docker push "discovery/my-server:sha-$CI_COMMIT_SHORT_SHA"

deploy_discovery:
  stage: deploy
  image: curlimages/curl:latest
  script:
    - |
      curl -s -X POST "$DISCOVERY_URL/api/ci/deploy" \
        -H "Content-Type: application/json" \
        -H "x-api-token: $DISCOVERY_TOKEN" \
        -d "{
          \"app_name\": \"my-server-app\",
          \"image\": \"discovery/my-server:sha-$CI_COMMIT_SHORT_SHA\",
          \"environment\": \"production\",
          \"idempotency_key\": \"build-$CI_COMMIT_SHORT_SHA\",
          \"config_ref\": {
            \"app_host\": \"myserver.example.com\",
            \"app_target_port\": 80,
            \"app_container_port\": 4000
          }
        }" > response.json
      cat response.json
```

---

## 3. Jenkins Pipeline Integration

If you prefer to orchestrate deployments using **Jenkins**, copy this stage into your declarative Jenkins pipeline:

```groovy
stage('Deploy to Discovery') {
    steps {
        script {
            def payload = """{
                "app_name": "my-server-app",
                "image": "discovery/my-server:sha-${env.GIT_COMMIT}",
                "environment": "production",
                "idempotency_key": "build-${env.BUILD_ID}",
                "config_ref": {
                    "app_host": "myserver.example.com",
                    "app_target_port": 80,
                    "app_container_port": 4000
                }
            }"""
            
            withCredentials([string(credentialsId: 'discovery-api-token', variable: 'TOKEN')]) {
                def response = httpRequest(
                    url: "https://discovery.example.com/api/ci/deploy",
                    httpMode: 'POST',
                    contentType: 'APPLICATION_JSON',
                    customHeaders: [[name: 'x-api-token', value: TOKEN]],
                    requestBody: payload
                )
                
                println("Response Status: " + response.status)
                println("Response Content: " + response.content)
                
                if (response.status != 200) {
                    error("❌ Discovery CD Deployment failed!")
                }
            }
        }
    }
}
```
Using these standard templates, your development teams can start deploying stateful servers with zero effort!
