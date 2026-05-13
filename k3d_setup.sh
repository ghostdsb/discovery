#!/bin/bash
set -e

CLUSTER_NAME="discovery-cluster"
REGISTRY_NAME="discovery-registry"
REGISTRY_PORT="5001"

echo "Checking if k3d is installed..."
if ! command -v k3d &> /dev/null; then
    echo "k3d not found. Please install it: brew install k3d"
    exit 1
fi

# Create registry if it doesn't exist
if ! k3d registry list | grep -q "$REGISTRY_NAME"; then
    echo "Creating registry $REGISTRY_NAME..."
    k3d registry create "$REGISTRY_NAME" --port "$REGISTRY_PORT"
fi

# Create cluster
if ! k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Creating cluster $CLUSTER_NAME..."
    k3d cluster create "$CLUSTER_NAME" \
        --registry-use "k3d-$REGISTRY_NAME:$REGISTRY_PORT" \
        --port "8080:80@loadbalancer" \
        --port "8443:443@loadbalancer" \
        --k3s-arg "--disable=traefik@server:0"
else
    echo "Cluster $CLUSTER_NAME already exists."
fi

# Install Nginx Ingress Controller
echo "Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Wait for Ingress Controller
echo "Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Install ArgoCD
echo "Installing ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Setup complete!"
echo "Registry: localhost:$REGISTRY_PORT"
echo "Kubeconfig: Use 'k3d cluster edit $CLUSTER_NAME' if needed"
