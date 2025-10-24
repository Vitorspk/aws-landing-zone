.PHONY: help fmt init-iam init-networking init-kubernetes plan-iam plan-networking plan-kubernetes apply-iam apply-networking apply-kubernetes destroy-all

help:
	@echo "AWS Landing Zone - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  fmt               - Format all Terraform files"
	@echo "  init-iam          - Initialize IAM Terraform"
	@echo "  init-networking   - Initialize Networking Terraform"
	@echo "  init-kubernetes   - Initialize Kubernetes Terraform"
	@echo "  plan-iam          - Plan IAM changes"
	@echo "  plan-networking   - Plan Networking changes"
	@echo "  plan-kubernetes   - Plan Kubernetes changes"
	@echo "  apply-iam         - Apply IAM changes"
	@echo "  apply-networking  - Apply Networking changes"
	@echo "  apply-kubernetes  - Apply Kubernetes changes"
	@echo "  destroy-all       - Destroy all infrastructure (use with caution!)"

fmt:
	@echo "Formatting all Terraform files..."
	terraform fmt -recursive terraform/00-iam/
	terraform fmt -recursive terraform/01-networking/
	terraform fmt -recursive terraform/02-kubernetes/
	@echo "✅ All files formatted!"

init-iam:
	cd terraform/00-iam && terraform init

init-networking:
	cd terraform/01-networking && terraform init

init-kubernetes:
	cd terraform/02-kubernetes && terraform init

plan-iam:
	cd terraform/00-iam && terraform plan

plan-networking:
	cd terraform/01-networking && terraform plan

plan-kubernetes:
	cd terraform/02-kubernetes && terraform plan

apply-iam:
	cd terraform/00-iam && terraform apply

apply-networking:
	cd terraform/01-networking && terraform apply

apply-kubernetes:
	cd terraform/02-kubernetes && terraform apply

destroy-all:
	@echo "⚠️  WARNING: This will destroy ALL infrastructure!"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read confirm
	cd terraform/02-kubernetes && terraform destroy
	cd terraform/01-networking && terraform destroy
	cd terraform/00-iam && terraform destroy
