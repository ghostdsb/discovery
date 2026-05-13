# Tiltfile for Discovery

# 1. Build the Elixir App
docker_build(
    'discovery-app',
    '.',
    dockerfile='dev.Dockerfile',
    live_update=[
        sync('./lib', '/home/elixir/app/lib'),
        sync('./assets', '/home/elixir/app/assets'),
        sync('./config', '/home/elixir/app/config'),
        # Run hot-recompile or release restart if needed
        # For releases, we might need a full restart or a signal
        run('kill -1 1', trigger=['./lib', './config'])
    ]
)

# 2. Deploy the App to K8s
# Assuming there's a deployment manifest in a standard location or we generate one
# For this example, let's assume we have a basic k8s/discovery.yaml or use a helm chart
# Since I don't see one in the file list, I'll create a minimal one or use the existing ones in priv/templates if applicable
# For now, let's use a k8s_yaml call if you have manifests, or just deploy the image.

k8s_yaml('k8s/dev-deployment.yaml')

# 3. Port Forwarding
k8s_resource('discovery-app', 
    port_forwards=['4000:4000'],
    labels=['app']
)

# 4. ArgoCD Resources
# If you have local manifests for ArgoCD apps
# k8s_yaml('argocd/application.yaml')

# Port forward ArgoCD Server
k8s_resource('argocd-server',
    port_forwards=['8080:8080'],
    namespace='argocd',
    labels=['gitops']
)

# 5. Local Registry
# Tilt handles this automatically if you use 'localhost:5001/discovery-app'
