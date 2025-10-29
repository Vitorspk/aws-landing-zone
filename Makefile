.PHONY: help init plan apply destroy cleanup reset validate format

# ==============================================================================
# AWS LANDING ZONE - MAKEFILE
# ==============================================================================

REGION ?= sa-east-1
CLUSTERS ?= all

help: ## Show this help message
	@echo "AWS Landing Zone - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ==============================================================================
# PREREQUISITES
# ==============================================================================

check: ## Check prerequisites (AWS CLI, credentials, backend)
	@chmod +x scripts/check-prerequisites.sh
	@./scripts/check-prerequisites.sh

setup-backend: ## Setup S3 bucket and DynamoDB table
	@chmod +x scripts/setup-backend.sh
	@./scripts/setup-backend.sh

# ==============================================================================
# CLEANUP
# ==============================================================================

cleanup: ## Cleanup conflicting CloudWatch log groups and K8s jobs
	@chmod +x scripts/cleanup-resources.sh
	@./scripts/cleanup-resources.sh

reset: ## Complete reset - destroy all infrastructure
	@chmod +x scripts/complete-reset.sh
	@./scripts/complete-reset.sh

cleanup-k8s: ## Cleanup Kubernetes jobs only
	@chmod +x scripts/cleanup-k8s-jobs.sh
	@./scripts/cleanup-k8s-jobs.sh

# ==============================================================================
# TERRAFORM OPERATIONS - LOCAL
# ==============================================================================

init: ## Initialize all Terraform phases
	@echo "Initializing Phase 0 - IAM..."
	@cd terraform/00-iam && terraform init -backend-config="region=$(REGION)"
	@echo ""
	@echo "Initializing Phase 1 - Networking..."
	@cd terraform/01-networking && terraform init -backend-config="region=$(REGION)"
	@echo ""
	@echo "Initializing Phase 2 - Kubernetes..."
	@cd terraform/02-kubernetes && terraform init -backend-config="region=$(REGION)"
	@echo ""
	@echo "✅ All phases initialized!"

plan: ## Run terraform plan for all phases
	@echo "Planning Phase 0 - IAM..."
	@cd terraform/00-iam && terraform plan -var="region=$(REGION)"
	@echo ""
	@echo "Planning Phase 1 - Networking..."
	@cd terraform/01-networking && terraform plan -var="region=$(REGION)"
	@echo ""
	@echo "Planning Phase 2 - Kubernetes..."
	@cd terraform/02-kubernetes && terraform plan -var="region=$(REGION)" -var="deploy_clusters=$(CLUSTERS)"
	@echo ""
	@echo "✅ Planning completed!"

apply-iam: ## Apply Phase 0 - IAM
	@cd terraform/00-iam && \
		terraform init -backend-config="region=$(REGION)" && \
		terraform apply -var="region=$(REGION)" -auto-approve

apply-networking: ## Apply Phase 1 - Networking
	@cd terraform/01-networking && \
		terraform init -backend-config="region=$(REGION)" && \
		terraform apply -var="region=$(REGION)" -auto-approve

apply-kubernetes: ## Apply Phase 2 - Kubernetes
	@cd terraform/02-kubernetes && \
		terraform init -backend-config="region=$(REGION)" && \
		terraform apply -var="region=$(REGION)" -var="deploy_clusters=$(CLUSTERS)" -auto-approve

apply-all: cleanup apply-iam apply-networking apply-kubernetes ## Apply all phases sequentially with cleanup

# ==============================================================================
# DESTROY
# ==============================================================================

destroy-kubernetes: ## Destroy Phase 2 - Kubernetes
	@cd terraform/02-kubernetes && \
		terraform init -backend-config="region=$(REGION)" && \
		terraform destroy -var="region=$(REGION)" -var="deploy_clusters=$(CLUSTERS)" -auto-approve

destroy-networking: ## Destroy Phase 1 - Networking
	@cd terraform/01-networking && \
		terraform init -backend-config="region=$(REGION)" && \
		terraform destroy -var="region=$(REGION)" -auto-approve

destroy-iam: ## Destroy Phase 0 - IAM
	@cd terraform/00-iam && \
		terraform init -backend-config="region=$(REGION)" && \
		terraform destroy -var="region=$(REGION)" -auto-approve

destroy-all: destroy-kubernetes destroy-networking destroy-iam cleanup ## Destroy all phases in reverse order

# ==============================================================================
# CODE QUALITY
# ==============================================================================

format: ## Format all Terraform files
	@chmod +x scripts/format-terraform.sh
	@./scripts/format-terraform.sh

validate: ## Validate all Terraform configurations
	@echo "Validating Phase 0 - IAM..."
	@cd terraform/00-iam && terraform init -backend=false && terraform validate
	@echo ""
	@echo "Validating Phase 1 - Networking..."
	@cd terraform/01-networking && terraform init -backend=false && terraform validate
	@echo ""
	@echo "Validating Phase 2 - Kubernetes..."
	@cd terraform/02-kubernetes && terraform init -backend=false && terraform validate
	@echo ""
	@echo "✅ All phases validated!"

# ==============================================================================
# UTILITIES
# ==============================================================================

outputs: ## Show outputs from all phases
	@echo "=== Phase 0 - IAM Outputs ==="
	@cd terraform/00-iam && terraform init -backend-config="region=$(REGION)" &>/dev/null && terraform output
	@echo ""
	@echo "=== Phase 1 - Networking Outputs ==="
	@cd terraform/01-networking && terraform init -backend-config="region=$(REGION)" &>/dev/null && terraform output
	@echo ""
	@echo "=== Phase 2 - Kubernetes Outputs ==="
	@cd terraform/02-kubernetes && terraform init -backend-config="region=$(REGION)" &>/dev/null && terraform output

state-list: ## List all resources in Terraform state
	@echo "=== IAM Resources ==="
	@cd terraform/00-iam && terraform init -backend-config="region=$(REGION)" &>/dev/null && terraform state list
	@echo ""
	@echo "=== Networking Resources ==="
	@cd terraform/01-networking && terraform init -backend-config="region=$(REGION)" &>/dev/null && terraform state list
	@echo ""
	@echo "=== Kubernetes Resources ==="
	@cd terraform/02-kubernetes && terraform init -backend-config="region=$(REGION)" &>/dev/null && terraform state list

clusters: ## List all EKS clusters
	@aws eks list-clusters --region $(REGION)

# ==============================================================================
# EXAMPLES
# ==============================================================================

# Deploy only dev cluster:
#   make apply-kubernetes CLUSTERS=dev
#
# Deploy dev and stg:
#   make apply-kubernetes CLUSTERS=dev,stg
#
# Use different region:
#   make apply-all REGION=us-east-1
#
# Check what will be created:
#   make plan
#
# Complete reset and fresh deploy:
#   make reset
#   make apply-all
