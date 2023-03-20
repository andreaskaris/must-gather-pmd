CONTAINER_RUNTIME ?= podman
IMAGE ?= quay.io/akaris/must-gather-pmd:v0.1

.PHONY: build-container
build-container: ## Build the container. CONTAINER_RUNTIME and IMAGE to override default behavior.
	$(CONTAINER_RUNTIME) build -t $(IMAGE) .

.PHONY: push-container
push-container: ## Push the container. CONTAINER_RUNTIME and IMAGE to override default behavior.
	$(CONTAINER_RUNTIME) push $(IMAGE)

# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

###################################################
# The below targets are for testing only.
###################################################
.PHONY: deploy-pod
deploy-pod:
	sed -i "s#^  newName:.*#  newName: $(IMAGE)#" "resources/kustomization.yaml"
	kubectl apply -k resources/

.PHONY: undeploy-pod
undeploy-pod:
	kubectl delete -k resources/
