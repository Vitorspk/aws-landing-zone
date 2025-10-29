.PHONY: help fmt init-iam init-networking init-kubernetes plan-iam plan-networking plan-kubernetes apply-iam apply-networking apply-kubernetes deploy-ingress destroy-all

# Get region from environment variable or use default
AWS_REGION ?= $(shell echo $$AWS_DEFAULT_REGION)
ifeq ($(AWS_REGION),)
	AWS_REGION = sa-east-1
endif

help:
	@echo "AWS Landing Zone - Makefile"
	@echo ""
	@echo "Current AWS Region: $(AWS_REGION)"
	@echo ""
	@echo "Available targets:"
	@echo "  fmt                - Format all Terraform files"
	@echo "  init-iam           - Initialize IAM Terraform"
	@echo "  init-networking    - Initialize Networking Terraform"
	@echo "  init-kubernetes    - Initialize Kubernetes Terraform"
	@echo "  plan-iam           - Plan IAM changes"
	@echo "  plan-networking    - Plan Networking changes"
	@echo "  plan-kubernetes    - Plan Kubernetes changes"
	@echo "  apply-iam          - Apply IAM changes"
	@echo "  apply-networking   - Apply Networking changes"
	@echo "  apply-kubernetes   - Apply Kubernetes changes"
	@echo "  deploy-ingress     - Deploy NGINX Ingress Controllers to all clusters"
	@echo "  destroy-all        - Destroy all infrastructure (use with caution!)"
	@echo ""
	@echo "Set custom region: export AWS_DEFAULT_REGION=us-east-1"

fmt:
	@echo "Formatting all Terraform files..."
	terraform fmt -recursive terraform/00-iam/
	terraform fmt -recursive terraform/01-networking/
	terraform fmt -recursive terraform/02-kubernetes/
	@echo "✅ All files formatted!"

init-iam:
	cd terraform/00-iam && terraform init -backend-config="region=$(AWS_REGION)"

init-networking:
	cd terraform/01-networking && terraform init -backend-config="region=$(AWS_REGION)"

init-kubernetes:
	cd terraform/02-kubernetes && terraform init -backend-config="region=$(AWS_REGION)"

plan-iam:
	cd terraform/00-iam && terraform plan -var="region=$(AWS_REGION)"

plan-networking:
	cd terraform/01-networking && terraform plan -var="region=$(AWS_REGION)"

plan-kubernetes:
	cd terraform/02-kubernetes && terraform plan -var="region=$(AWS_REGION)"

apply-iam:
	cd terraform/00-iam && terraform apply -var="region=$(AWS_REGION)"

apply-networking:
	cd terraform/01-networking && terraform apply -var="region=$(AWS_REGION)"

apply-kubernetes:
	cd terraform/02-kubernetes && terraform apply -var="region=$(AWS_REGION)"

deploy-ingress:
	@echo "Deploying NGINX Ingress Controllers to all clusters..."
	@chmod +x scripts/deploy-ingress-controllers.sh
	@./scripts/deploy-ingress-controllers.sh eks-dev $(AWS_REGION)
	@./scripts/deploy-ingress-controllers.sh eks-stg $(AWS_REGION)
	@./scripts/deploy-ingress-controllers.sh eks-prd $(AWS_REGION)
	@./scripts/deploy-ingress-controllers.sh eks-sdx $(AWS_REGION)
	@echo "✅ NGINX Ingress Controllers deployed to all clusters!"

destroy-all:
	@echo "⚠️  WARNING: This will destroy ALL infrastructure!"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read confirm
	cd terraform/02-kubernetes && terraform destroy -var="region=$(AWS_REGION)"
	cd terraform/01-networking && terraform destroy -var="region=$(AWS_REGION)"
	cd terraform/00-iam && terraform destroy -var="region=$(AWS_REGION)"
