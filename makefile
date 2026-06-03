DOCKER_REGISTRY ?= discovery
VERSION_DEV = 0.2.5
VERSION_PROD = 0.1.0

commit:
	mix test
	mix format
	mix credo --strict
	git add .
	git cz

commit-release-major:
	mix bump_release major
	mix test
	mix format
	mix credo --strict
	git add .
	git cz

commit-release-minor:
	mix bump_release minor
	mix test
	mix format
	mix credo --strict
	git add .
	git cz

commit-release-patch:
	mix bump_release patch
	mix test
	mix format
	mix credo --strict
	git add .
	git cz

dev-release:
	mix deps.get
	mix compile
	mix release

builddockerprod: 
	docker build --tag $(DOCKER_REGISTRY)/discovery .
	docker tag $(DOCKER_REGISTRY)/discovery $(DOCKER_REGISTRY)/discovery:$(VERSION_PROD)

builddockerdev: 
	docker build --file dev.Dockerfile --tag $(DOCKER_REGISTRY)/discovery .
	docker tag $(DOCKER_REGISTRY)/discovery $(DOCKER_REGISTRY)/discovery:$(VERSION_DEV)

pushdockerdev: builddockerdev
	docker push $(DOCKER_REGISTRY)/discovery:$(VERSION_DEV)

# pushdockerprod: builddockerprod
# 	docker push $(DOCKER_REGISTRY)/discovery:$(VERSION_PROD)

rundockerprod: 
	docker run --name discovery-$(VERSION_PROD) --publish 6968:6968 --detach --env DISCOVERY_PORT=6968 \
	--env SECRET_KEY_BASE=${SECRET_KEY_BASE} $(DOCKER_REGISTRY)/discovery:$(VERSION_PROD)

rundockerdev: builddockerdev
	docker run --name discovery-$(VERSION_DEV) --publish 6966:6966 --detach --env DISCOVERY_PORT=6966 \
	--env SECRET_KEY_BASE=${SECRET_KEY_BASE} $(DOCKER_REGISTRY)/discovery:$(VERSION_DEV)

# Redeploy updated code to the local Compose k3s cluster
k8s-redeploy:
	@echo "Building docker image discovery-app:latest..."
	docker build -f dev.Dockerfile -t discovery-app:latest .
	@echo "Saving local image discovery-app:latest..."
	docker save discovery-app:latest -o discovery-tmp.tar
	@echo "Copying to k3s container..."
	docker cp discovery-tmp.tar discovery-k3s-server-1:/discovery-tmp.tar
	@echo "Importing inside k3s containerd..."
	docker exec discovery-k3s-server-1 ctr -n k8s.io image import /discovery-tmp.tar
	docker exec discovery-k3s-server-1 rm /discovery-tmp.tar
	rm discovery-tmp.tar
	@echo "Applying manifests and rolling restart..."
	@if [ -f data/k3s/kubeconfig.yaml ]; then \
		KUBECONFIG=data/k3s/kubeconfig.yaml kubectl apply -f k8s/dev-deployment.yaml; \
		KUBECONFIG=data/k3s/kubeconfig.yaml kubectl rollout restart deployment/discovery-app -n discovery; \
	else \
		kubectl apply -f k8s/dev-deployment.yaml; \
		kubectl rollout restart deployment/discovery-app -n discovery; \
	fi
	@echo "Redeployed successfully!"