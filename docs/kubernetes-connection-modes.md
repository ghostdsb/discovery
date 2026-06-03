# Kubernetes Connection Modes & Local Cluster Guide

This guide details how to configure **Discovery** to connect to your Kubernetes cluster in development and production environments.

---

## 🛠️ Kubernetes Connection Modes

Discovery supports two primary connection modes configured via the `connection_method` key in your configuration files (`config/config.exs`, `config/dev.exs`, or `config/prod.exs`).

| Connection Mode | Target Environment | Infrastructure Dependency | Description |
| :--- | :--- | :--- | :--- |
| **`:kube_config`** | Local Development | Local/Remote K8s Cluster | Connects to a cluster (e.g. k3d, minikube) by loading context from the developer's local `~/.kube/config` file. |
| **`:service_account`**| Production / Staging | Live Pod (In-Cluster) | Authenticates seamlessly using the local Service Account tokens automatically mounted inside the Pod at runtime. |

---

### 1. 💻 `:kube_config` (Local Cluster Mode)

Used to connect to a local or remote Kubernetes cluster from your development machine.

#### ⚙️ Configuration Setup
In `config/dev.exs`, set:
```elixir
config :discovery,
  connection_method: :kube_config
```

#### 🚀 How to Run & Use
1. **Ensure the namespace exists**:
   ```bash
   kubectl create namespace discovery
   ```
2. **Verify your active context**:
   Ensure your local shell is pointing to the correct development cluster:
   ```bash
   kubectl config current-context
   ```
3. **Start the Phoenix server**:
   ```bash
   mix phx.server
   ```
   Discovery will automatically read your `~/.kube/config` credentials and connect to the cluster's API endpoint.

---

### 2. ☸️ `:service_account` (In-Cluster Mode)

This is the standard mode for production deployments running inside the Kubernetes cluster.

#### ⚙️ Configuration Setup
In `config/prod.exs` or `config/runtime.exs`:
```elixir
config :discovery,
  connection_method: :service_account
```

#### 🚀 Deployment Setup

1. **Deploy RBAC resources**:
   Discovery needs a Service Account with permissions to get, list, and watch Pods in the `discovery` namespace. Create a manifest `rbac.yaml`:
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
   Apply it:
   ```bash
   kubectl apply -f rbac.yaml
   ```

2. **Deploy Discovery App**:
   Ensure your application pod spec uses the configured service account:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: discovery-app
     namespace: discovery
   spec:
     template:
       spec:
         serviceAccountName: discovery-service-account
         containers:
         - name: discovery
           image: discovery-app:latest
   ```

---

## 🐳 Starting a Local k3d Cluster

For local verification, you can spin up a lightweight Kubernetes cluster inside Docker using **k3d**.

### 🚀 Step-by-Step Cluster Setup
1. **Execute the Setup Script**:
   We provide an automated installation script in the root directory:
   ```bash
   bash k3d_setup.sh
   ```
2. **Verify Cluster State**:
   Once the script completes, run:
   ```bash
   kubectl get nodes
   ```
3. **Deploy manifests**:
   Deploy the Discovery app and tracked services inside the cluster to test live event synchronization:
   ```bash
   kubectl apply -f k8s/dev-deployment.yaml
   ```
