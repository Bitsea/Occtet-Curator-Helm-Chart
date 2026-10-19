# Makefile for Occtet Curator Helm Chart

.PHONY: help install upgrade uninstall lint test template clean namespace check-helm list logs port-forward deps secrets
.PHONY: secrets-create secrets-check secrets-view secrets-get secrets-delete secrets-backup
.PHONY: upgrade-nowait watch-pods pods-status pods-not-ready describe-pods
.PHONY: logs-frontend logs-backend logs-postgresql logs-nats logs-vulnerability

# Ensure we use bash for commands that need it
SHELL := /bin/bash

# Variables
CHART_NAME := occtet-curator
RELEASE_NAME := occtet-curator
NAMESPACE ?= curator
CHART_PATH := ./occtet-curator

# Values files applied in this order after the chart defaults (occtet-curator/values.yaml);
# empty: the chart defaults only. For instance: make install VALUES_FILES="my-values.yaml"
VALUES_FILES ?=
# kubectl context of every command (empty: the current context)
KUBE_CONTEXT ?=

# The chart places its resources in global.namespace, not in the release namespace
HELM_VALUES = $(addprefix --values ,$(VALUES_FILES)) --set global.namespace=$(NAMESPACE)
KUBECTL = kubectl $(if $(KUBE_CONTEXT),--context $(KUBE_CONTEXT))
HELM = helm $(if $(KUBE_CONTEXT),--kube-context $(KUBE_CONTEXT))

# Secret names
SECRET_NAME := occtet-curator-secrets

# Colors for output
GREEN := $(shell printf '\033[0;32m')
YELLOW := $(shell printf '\033[1;33m')
RED := $(shell printf '\033[0;31m')
NC := $(shell printf '\033[0m')

help: ## Display help
	@echo "$(GREEN)Occtet Curator Helm Chart - Available commands:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

check-helm: ## Check if Helm is installed
	@which helm > /dev/null || (echo "$(RED)Helm is not installed$(NC)" && exit 1)
	@echo "$(GREEN)✓ Helm is installed (version: $$(helm version --short))$(NC)"

# The namespace is not part of the release: if it were, any release rendered without it
# (wrong chart path, helm uninstall) would delete the namespace and every volume in it.
namespace: check-helm ## Create the namespace
	@$(KUBECTL) get namespace $(NAMESPACE) > /dev/null 2>&1 || $(KUBECTL) create namespace $(NAMESPACE)
	@echo "$(GREEN)✓ Namespace $(NAMESPACE) is ready$(NC)"

# The ORT Server and Keycloak credentials come from those systems, so the target prompts for them:
# hidden input keeps them out of the shell history and is not expanded by make.
# A value set in the environment (DB_USER, DB_NAME, DB_PASSWORD, ORT_USERNAME, ORT_PASSWORD,
# KEYCLOAK_CLIENT_ID, KEYCLOAK_CLIENT_SECRET) is used without prompting, even when empty (default
# value), so that a script can create the secret.
# PostgreSQL keeps the user, database and password of its first start: when the database volume
# already exists, enter its current values instead of the defaults.
secrets-create: namespace ## Create the unified secret (prompts for the ORT and Keycloak credentials not set in the environment)
	@if $(KUBECTL) get secret $(SECRET_NAME) -n $(NAMESPACE) > /dev/null 2>&1; then \
		echo "$(RED)✗ $(SECRET_NAME) already exists in $(NAMESPACE)$(NC)"; \
		echo "$(YELLOW)Run 'make secrets-delete' first to recreate it$(NC)"; \
		exit 1; \
	fi
	@ask() { \
		if [ -n "$${!1+set}" ]; then echo "$$2 from the environment ($$1)"; \
		elif [ "$$3" = hidden ]; then read -rsp "$$2: " "$$1"; echo; \
		else read -rp "$$2: " "$$1"; fi; \
	}; \
	ask DB_USER "PostgreSQL user [curator]"; \
	ask DB_NAME "PostgreSQL database [curator]"; \
	ask DB_PASSWORD "PostgreSQL password [generated]" hidden; \
	ask ORT_USERNAME "ORT Server username"; \
	ask ORT_PASSWORD "ORT Server password" hidden; \
	ask KEYCLOAK_CLIENT_ID "Keycloak client ID [api-access]"; \
	ask KEYCLOAK_CLIENT_SECRET "Keycloak client secret" hidden; \
	for var in ORT_USERNAME ORT_PASSWORD KEYCLOAK_CLIENT_SECRET; do \
		if [ -z "$${!var}" ]; then echo "$(RED)✗ $$var is required$(NC)"; exit 1; fi; \
	done; \
	$(KUBECTL) create secret generic $(SECRET_NAME) -n $(NAMESPACE) \
		--from-literal=username="$${DB_USER:-curator}" \
		--from-literal=database="$${DB_NAME:-curator}" \
		--from-literal=postgres-password="$${DB_PASSWORD:-$$(openssl rand -hex 24)}" \
		--from-literal=ort-username="$$ORT_USERNAME" \
		--from-literal=ort-password="$$ORT_PASSWORD" \
		--from-literal=keycloak-client-id="$${KEYCLOAK_CLIENT_ID:-api-access}" \
		--from-literal=keycloak-client-secret="$$KEYCLOAK_CLIENT_SECRET" > /dev/null
	@echo "$(GREEN)✓ $(SECRET_NAME) created in $(NAMESPACE)$(NC)"

secrets-check: ## Check the unified secret (database + frontend credentials)
	@echo "$(YELLOW)Checking secrets...$(NC)"
	@if $(KUBECTL) get secret $(SECRET_NAME) -n $(NAMESPACE) > /dev/null 2>&1; then \
		echo "$(GREEN)✓ $(SECRET_NAME)$(NC)"; \
		$(KUBECTL) get secret $(SECRET_NAME) -n $(NAMESPACE) -o jsonpath='{.data}' | jq -r 'keys[]' | sed 's/^/  - /'; \
	else \
		echo "$(RED)✗ $(SECRET_NAME) not found$(NC)"; \
		echo "$(YELLOW)Run 'make secrets-create' to create it$(NC)"; \
		exit 1; \
	fi

secrets-view: ## Display secret keys (not values)
	@$(KUBECTL) describe secret $(SECRET_NAME) -n $(NAMESPACE) 2>/dev/null || echo "$(RED)Secret $(SECRET_NAME) not found$(NC)"

secrets-get: ## Get all secret values (CAUTION: displays passwords)
	@echo "$(RED)⚠ WARNING: This will display passwords in clear text!$(NC)"
	@echo "$(YELLOW)=== $(SECRET_NAME) ===$(NC)"
	@echo "  DB User:            $$($(KUBECTL) get secret $(SECRET_NAME) -n $(NAMESPACE) -o jsonpath='{.data.username}' | base64 -d 2>/dev/null || echo 'N/A')"
	@echo "  DB Password:        $$($(KUBECTL) get secret $(SECRET_NAME) -n $(NAMESPACE) -o jsonpath='{.data.postgres-password}' | base64 -d 2>/dev/null || echo 'N/A')"
	@echo "  Database:           $$($(KUBECTL) get secret $(SECRET_NAME) -n $(NAMESPACE) -o jsonpath='{.data.database}' | base64 -d 2>/dev/null || echo 'N/A')"
	@echo "  ORT Username:       $$($(KUBECTL) get secret $(SECRET_NAME) -n $(NAMESPACE) -o jsonpath='{.data.ort-username}' | base64 -d 2>/dev/null || echo 'N/A')"
	@echo "  ORT Password:       $$($(KUBECTL) get secret $(SECRET_NAME) -n $(NAMESPACE) -o jsonpath='{.data.ort-password}' | base64 -d 2>/dev/null || echo 'N/A')"
	@echo "  Keycloak Client ID: $$($(KUBECTL) get secret $(SECRET_NAME) -n $(NAMESPACE) -o jsonpath='{.data.keycloak-client-id}' | base64 -d 2>/dev/null || echo 'N/A')"
	@echo "  Keycloak Secret:    $$($(KUBECTL) get secret $(SECRET_NAME) -n $(NAMESPACE) -o jsonpath='{.data.keycloak-client-secret}' | base64 -d 2>/dev/null || echo 'N/A')"

secrets-delete: ## Delete the unified secret
	@echo "$(RED)⚠ WARNING: This will delete all secrets!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(KUBECTL) delete secret $(SECRET_NAME) -n $(NAMESPACE) 2>/dev/null && echo "$(GREEN)✓ $(SECRET_NAME) deleted$(NC)" || echo "$(YELLOW)  $(SECRET_NAME) not found$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

secrets-backup: ## Backup the unified secret to file (CAUTION: contains passwords in base64)
	@echo "$(RED)⚠ WARNING: This file will contain passwords in base64!$(NC)"
	@$(KUBECTL) get secret $(SECRET_NAME) -n $(NAMESPACE) -o yaml > secrets-backup.yaml 2>/dev/null || echo "$(YELLOW)  $(SECRET_NAME) not found$(NC)"
	@echo "$(GREEN)✓ Backup created: secrets-backup.yaml$(NC)"
	@echo "$(YELLOW)Keep this file secure! It is already in .gitignore$(NC)"

deps: check-helm ## Install Helm dependencies (PostgreSQL, etc.) at the versions of Chart.lock
	@echo "$(YELLOW)Installing Helm dependencies (OCI)...$(NC)"
	@helm dependency build $(CHART_PATH) || helm dependency update $(CHART_PATH)
	@echo "$(GREEN)✓ Dependencies installed successfully$(NC)"

deps-list: check-helm ## List current dependencies
	@echo "$(YELLOW)=== Chart Dependencies ===$(NC)"
	@helm dependency list $(CHART_PATH)

deps-update: check-helm ## Update dependencies to latest versions
	@echo "$(YELLOW)Updating dependencies...$(NC)"
	@helm dependency update $(CHART_PATH) --skip-refresh
	@echo "$(GREEN)✓ Dependencies updated$(NC)"
	@$(MAKE) deps-list

lint: check-helm ## Validate the Helm chart
	@echo "$(YELLOW)Validating chart...$(NC)"
	@helm lint $(CHART_PATH) $(HELM_VALUES)
	@echo "$(GREEN)✓ Chart validated successfully$(NC)"

template: check-helm ## Generate manifests without installing
	@echo "$(YELLOW)Generating manifests...$(NC)"
	@helm template $(RELEASE_NAME) $(CHART_PATH) --namespace $(NAMESPACE) $(HELM_VALUES)

template-debug: check-helm ## Generate manifests with debug
	@echo "$(YELLOW)Generating manifests in debug mode...$(NC)"
	@helm template $(RELEASE_NAME) $(CHART_PATH) --namespace $(NAMESPACE) $(HELM_VALUES) --debug

dry-run: check-helm namespace ## Installation simulation
	@echo "$(YELLOW)Simulating installation...$(NC)"
	@$(HELM) install $(RELEASE_NAME) $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		$(HELM_VALUES) \
		--dry-run --debug

install: check-helm namespace deps lint ## Install the chart (VALUES_FILES)
	@echo "$(YELLOW)Installing chart $(CHART_NAME)...$(NC)"
	@$(HELM) install $(RELEASE_NAME) $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		$(HELM_VALUES) \
		--wait \
		--timeout 20m
	@echo "$(GREEN)✓ Chart installed successfully$(NC)"
	@echo "$(YELLOW)=== Deployment Status ===$(NC)"
	@$(HELM) status $(RELEASE_NAME) -n $(NAMESPACE) 2>/dev/null || echo "$(RED)Chart not installed$(NC)"

install-custom: check-helm namespace ## Install with custom values file (usage: make install-custom VALUES=custom-values.yaml)
	@if [ -z "$(VALUES)" ]; then \
		echo "$(RED)Error: Specify VALUES=your-file.yaml$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Installing with $(VALUES)...$(NC)"
	@$(HELM) install $(RELEASE_NAME) $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		--values $(VALUES) \
		--wait \
		--timeout 20m
	@echo "$(GREEN)✓ Chart installed successfully$(NC)"

upgrade: check-helm ## Upgrade the chart (or install if not present)
	@echo "$(YELLOW)Upgrading chart...$(NC)"
	@$(HELM) upgrade $(RELEASE_NAME) $(CHART_PATH) \
		--install \
		--namespace $(NAMESPACE) \
		$(HELM_VALUES)
	@echo "$(GREEN)✓ Chart upgraded successfully$(NC)"
	@echo "$(YELLOW)=== Deployment Status ===$(NC)"
	@$(HELM) status $(RELEASE_NAME) -n $(NAMESPACE) 2>/dev/null || echo "$(RED)Chart not installed$(NC)"


rollback: check-helm ## Rollback to previous release version
	@echo "$(YELLOW)Rolling back to previous version...$(NC)"
	@$(HELM) rollback $(RELEASE_NAME) -n $(NAMESPACE)
	@echo "$(GREEN)✓ Rollback completed$(NC)"
	@$(HELM) status $(RELEASE_NAME) -n $(NAMESPACE)

rollback-version: check-helm ## Rollback to specific version (usage: make rollback-version VERSION=3)
	@if [ -z "$(VERSION)" ]; then \
		echo "$(RED)Error: Specify VERSION=number$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Rolling back to version $(VERSION)...$(NC)"
	@$(HELM) rollback $(RELEASE_NAME) $(VERSION) -n $(NAMESPACE)
	@echo "$(GREEN)✓ Rollback to version $(VERSION) completed$(NC)"

history: check-helm ## Display release history
	@echo "$(YELLOW)=== Release History ===$(NC)"
	@$(HELM) history $(RELEASE_NAME) -n $(NAMESPACE)

uninstall: check-helm ## Uninstall the chart
	@echo "$(YELLOW)Uninstalling chart...$(NC)"
	@$(HELM) uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)
	@echo "$(GREEN)✓ Chart uninstalled successfully$(NC)"
	@echo "$(YELLOW)Note: PVCs and secrets are not automatically deleted$(NC)"
	@echo "To delete PVCs: make clean-pvcs"
	@echo "To delete secrets: make secrets-delete"

clean-all: uninstall clean-pvcs secrets-delete ## Uninstall and delete all data and secrets
	@echo "$(GREEN)✓ Complete cleanup done$(NC)"

status: ## Display deployment status
	@echo "$(YELLOW)=== Deployment Status ===$(NC)"
	@$(HELM) status $(RELEASE_NAME) -n $(NAMESPACE) 2>/dev/null || echo "$(RED)Chart not installed$(NC)"

list: check-helm ## List Helm releases
	@echo "$(YELLOW)=== Helm Releases ===$(NC)"
	@$(HELM) list -n $(NAMESPACE)

list-all: check-helm ## List all Helm releases
	@echo "$(YELLOW)=== All Helm Releases ===$(NC)"
	@$(HELM) list --all-namespaces

pods: ## Display all pods
	@echo "$(YELLOW)=== Pods in namespace $(NAMESPACE) ===$(NC)"
	@$(KUBECTL) get pods -n $(NAMESPACE) -o wide

watch-pods: ## Watch pods in real-time
	@echo "$(YELLOW)Watching pods in $(NAMESPACE) (Ctrl+C to exit)...$(NC)"
	@$(KUBECTL) get pods -n $(NAMESPACE) -w

pods-status: ## Display detailed pod status with restarts
	@echo "$(YELLOW)=== Detailed Pod Status ===$(NC)"
	@$(KUBECTL) get pods -n $(NAMESPACE) -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
READY:.status.conditions[?(@.type==\"Ready\")].status,\
RESTARTS:.status.containerStatuses[0].restartCount,\
AGE:.metadata.creationTimestamp

pods-not-ready: ## Show only pods that are not ready
	@echo "$(YELLOW)=== Pods Not Ready ===$(NC)"
	@$(KUBECTL) get pods -n $(NAMESPACE) --field-selector=status.phase!=Running,status.phase!=Succeeded

describe-pods: ## Describe all pods (useful for debugging)
	@echo "$(YELLOW)=== Describing all pods ===$(NC)"
	@$(KUBECTL) describe pods -n $(NAMESPACE)

logs-frontend: ## Get frontend logs
	@echo "$(YELLOW)=== Frontend Logs ===$(NC)"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app.kubernetes.io/component=frontend --tail=100

logs-backend: ## Get backend services logs (all)
	@echo "$(YELLOW)=== Backend Services Logs ===$(NC)"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app.kubernetes.io/component=backend --tail=50 --prefix=true

logs-postgresql: ## Get PostgreSQL logs
	@echo "$(YELLOW)=== PostgreSQL Logs ===$(NC)"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app.kubernetes.io/name=postgresql --tail=100

logs-nats: ## Get NATS logs
	@echo "$(YELLOW)=== NATS Logs ===$(NC)"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app.kubernetes.io/component=nats --tail=100

services: ## Display all services
	@echo "$(YELLOW)=== Services in namespace $(NAMESPACE) ===$(NC)"
	@$(KUBECTL) get svc -n $(NAMESPACE) -o wide

pvcs: ## Display all PVCs
	@echo "$(YELLOW)=== PVCs in namespace $(NAMESPACE) ===$(NC)"
	@$(KUBECTL) get pvc -n $(NAMESPACE)

all-resources: ## Display all resources
	@echo "$(YELLOW)=== All resources in namespace $(NAMESPACE) ===$(NC)"
	@$(KUBECTL) get all,pvc,cm,secret -n $(NAMESPACE)

clean-pvcs: ## Delete all PVCs
	@echo "$(RED)⚠ WARNING: This will delete all persistent data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(KUBECTL) delete pvc -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME); \
		echo "$(GREEN)✓ PVCs deleted$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

describe-frontend: ## Describe frontend pod
	@$(KUBECTL) describe pod -n $(NAMESPACE) -l app.kubernetes.io/component=frontend

describe-postgresql: ## Describe PostgreSQL pod
	@$(KUBECTL) describe pod -n $(NAMESPACE) -l app.kubernetes.io/name=postgresql

logs-vulnerability: ## Display vulnerability service logs
	@echo "$(YELLOW)=== Vulnerability Service Logs ===$(NC)"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app.kubernetes.io/service=vulnerability-service --tail=100 -f

port-forward-frontend: ## Port-forward to frontend (localhost:8090)
	@echo "$(GREEN)Port-forwarding frontend to http://localhost:8090$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to stop$(NC)"
	@$(KUBECTL) port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME)-frontend 8090:8090

port-forward-postgresql: ## Port-forward to PostgreSQL (localhost:5432)
	@echo "$(GREEN)Port-forwarding PostgreSQL to localhost:5432$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to stop$(NC)"
	@$(KUBECTL) port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME)-postgresql 5432:5432

port-forward-nats: ## Port-forward to NATS (localhost:4222)
	@echo "$(GREEN)Port-forwarding NATS to localhost:4222$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to stop$(NC)"
	@$(KUBECTL) port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME)-nats 4222:4222

shell-frontend: ## Open a shell in the frontend pod
	@$(KUBECTL) exec -it -n $(NAMESPACE) $$($(KUBECTL) get pod -n $(NAMESPACE) -l app.kubernetes.io/component=frontend -o jsonpath='{.items[0].metadata.name}') -- /bin/bash

shell-postgresql: ## Open a psql shell in PostgreSQL
	@$(KUBECTL) exec -it -n $(NAMESPACE) $$($(KUBECTL) get pod -n $(NAMESPACE) -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}') -- psql -U occtetuser -d occtet_boc

restart-frontend: ## Restart the frontend
	@echo "$(YELLOW)Restarting frontend...$(NC)"
	@$(KUBECTL) rollout restart deployment -n $(NAMESPACE) $(RELEASE_NAME)-frontend
	@$(KUBECTL) rollout status deployment -n $(NAMESPACE) $(RELEASE_NAME)-frontend
	@echo "$(GREEN)✓ Frontend restarted$(NC)"

restart-backend: ## Restart all backend services
	@echo "$(YELLOW)Restarting backend services...$(NC)"
	@$(KUBECTL) rollout restart deployment -n $(NAMESPACE) -l app.kubernetes.io/component=backend
	@echo "$(GREEN)✓ Backend services restarted$(NC)"

restart-all: ## Restart all deployments
	@echo "$(YELLOW)Restarting all deployments...$(NC)"
	@$(KUBECTL) rollout restart deployment -n $(NAMESPACE)
	@echo "$(GREEN)✓ All deployments restarted$(NC)"

scale-frontend: ## Scale the frontend (usage: make scale-frontend REPLICAS=3)
	@if [ -z "$(REPLICAS)" ]; then \
		echo "$(RED)Error: Specify REPLICAS=number$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Scaling frontend to $(REPLICAS) replicas...$(NC)"
	@$(KUBECTL) scale deployment -n $(NAMESPACE) $(RELEASE_NAME)-frontend --replicas=$(REPLICAS)
	@echo "$(GREEN)✓ Frontend scaled$(NC)"

watch: ## Watch pods in real-time
	@watch -n 2 $(KUBECTL) get pods -n $(NAMESPACE)

events: ## Display recent events
	@echo "$(YELLOW)=== Recent Events ===$(NC)"
	@$(KUBECTL) get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -20

test: lint template ## Test the chart
	@echo "$(YELLOW)Testing chart...$(NC)"
	@helm template $(RELEASE_NAME) $(CHART_PATH) --namespace $(NAMESPACE) $(HELM_VALUES) > /dev/null
	@echo "$(GREEN)✓ Tests passed$(NC)"

package: check-helm lint ## Package the chart
	@echo "$(YELLOW)Packaging chart...$(NC)"
	@helm package $(CHART_PATH)
	@echo "$(GREEN)✓ Chart packaged$(NC)"

values: ## Display the chart defaults, then the values files (VALUES_FILES)
	@cat $(CHART_PATH)/values.yaml $(VALUES_FILES)

info: ## Display chart information
	@echo "$(YELLOW)=== Chart Information ===$(NC)"
	@helm show chart $(CHART_PATH)

clean: ## Clean temporary files
	@echo "$(YELLOW)Cleaning temporary files...$(NC)"
	@rm -f *.tgz
	@echo "$(GREEN)✓ Cleanup done$(NC)"

.DEFAULT_GOAL := help
