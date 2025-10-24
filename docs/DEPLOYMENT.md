# AWS Landing Zone - Deployment Guide

This guide provides step-by-step instructions for deploying the AWS Landing Zone infrastructure.

## Prerequisites

Before starting the deployment, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** >= 1.5.0 installed
4. **kubectl** installed (for EKS cluster interaction)
5. **S3 bucket** for Terraform state
6. **DynamoDB table** for state locking

## Initial Setup

### 1. Create S3 Bucket for Terraform State

```bash
# Create S3 bucket
aws s3 mb s3://vschiavo-home-terraform-state --region sa-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket vschiavo-home-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket vschiavo-home-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### 2. Create DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region sa-east-1
```

### 3. Run Pre-Deployment Check

```bash
chmod +x scripts/pre-deployment-check.sh
./scripts/pre-deployment-check.sh
```

## Deployment Order

The infrastructure must be deployed in the following order:

1. **Phase 0: IAM** - IAM Roles and Policies
2. **Phase 1: Networking** - VPC, Subnets, NAT Gateway
3. **Phase 2: Kubernetes** - EKS Clusters

### Phase 0: IAM Deployment

Deploy IAM roles and policies that will be used by EKS clusters and node groups.

```bash
cd terraform/00-iam

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Return to root directory
cd ../..
```

**What gets created:**
- EKS cluster IAM roles (one per environment)
- EKS node group IAM roles (one per environment)
- AWS Load Balancer Controller IAM policy
- EBS CSI Driver IAM policy

### Phase 1: Networking Deployment

Deploy the VPC, subnets, NAT Gateway, and security groups.

```bash
cd terraform/01-networking

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Return to root directory
cd ../..
```

**What gets created:**
- VPC with CIDR 10.0.0.0/8
- Public subnets across 2 AZs
- Private subnets for each environment (dev, stg, prd, sdx) across 2 AZs
- Internet Gateway
- NAT Gateways (one per AZ)
- Route Tables
- Security Groups for EKS clusters and nodes
- VPC Endpoints (S3, ECR, EC2, STS)
- VPC Flow Logs

### Phase 2: Kubernetes Deployment

Deploy EKS clusters for all environments.

```bash
cd terraform/02-kubernetes

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Return to root directory
cd ../..
```

**What gets created:**
- EKS Cluster for dev environment
- EKS Cluster for stg environment
- EKS Cluster for prd environment
- EKS Cluster for sdx environment
- Node Groups for each cluster
- OIDC providers for IRSA
- EKS Addons (VPC CNI, CoreDNS, Kube-proxy, EBS CSI Driver)
- CloudWatch Log Groups

## Using Makefile

You can also use the provided Makefile for easier deployment:

```bash
# Format all Terraform files
make fmt

# Initialize all phases
make init-iam
make init-networking
make init-kubernetes

# Plan all phases
make plan-iam
make plan-networking
make plan-kubernetes

# Apply all phases
make apply-iam
make apply-networking
make apply-kubernetes
```

## Post-Deployment

### Configure kubectl for EKS Clusters

After deploying the EKS clusters, configure kubectl to interact with them:

```bash
# Dev cluster
aws eks update-kubeconfig --name eks-dev --region sa-east-1

# Stg cluster
aws eks update-kubeconfig --name eks-stg --region sa-east-1

# Prd cluster
aws eks update-kubeconfig --name eks-prd --region sa-east-1

# Sdx cluster
aws eks update-kubeconfig --name eks-sdx --region sa-east-1
```

### Verify Cluster Access

```bash
# List all contexts
kubectl config get-contexts

# Switch to desired cluster
kubectl config use-context <cluster-arn>

# Verify nodes
kubectl get nodes

# Verify pods
kubectl get pods -A
```

### Install AWS Load Balancer Controller (Optional)

For ingress support, install the AWS Load Balancer Controller:

```bash
# Add EKS chart repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

## Destroying Infrastructure

To destroy the infrastructure, run in reverse order:

```bash
# WARNING: This will destroy all infrastructure!

# Phase 2: Kubernetes
cd terraform/02-kubernetes
terraform destroy
cd ../..

# Phase 1: Networking
cd terraform/01-networking
terraform destroy
cd ../..

# Phase 0: IAM
cd terraform/00-iam
terraform destroy
cd ../..
```

Or use the Makefile:

```bash
make destroy-all
```

## Troubleshooting

### Error: S3 bucket not found

Ensure the S3 bucket exists and you have access to it:

```bash
aws s3 ls s3://vschiavo-home-terraform-state
```

### Error: DynamoDB table not found

Ensure the DynamoDB table exists:

```bash
aws dynamodb describe-table --table-name terraform-state-lock
```

### Error: Insufficient IAM permissions

Ensure your AWS credentials have the necessary permissions to create:
- IAM roles and policies
- VPC and networking resources
- EKS clusters and node groups
- CloudWatch log groups

### EKS Cluster Creation Timeout

EKS cluster creation can take 10-15 minutes. If it times out:
- Check AWS Console for cluster status
- Review CloudWatch logs for errors
- Verify security group rules allow cluster-to-node communication

## Support

For issues or questions:
- Check the [AWS EKS documentation](https://docs.aws.amazon.com/eks/)
- Review [Terraform AWS Provider documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- Open an issue in the repository
