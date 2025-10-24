# AWS Landing Zone

Complete AWS infrastructure automation using Terraform and GitHub Actions.

## Architecture

This project implements a three-phase infrastructure deployment:

- **Phase 0: IAM** - IAM Roles and Policies
- **Phase 1: Networking** - VPC, subnets, NAT Gateway, security groups
- **Phase 2: Kubernetes** - Four EKS clusters (dev, stg, prd, sdx)

## Structure

```
aws-landing-zone/
├── terraform/
│   ├── 00-iam/          # IAM Roles and Policies
│   ├── 01-networking/    # VPC and networking
│   └── 02-kubernetes/    # EKS clusters
├── manifests/            # Kubernetes manifests
├── scripts/              # Utility scripts
└── .github/workflows/    # GitHub Actions
```

## Deployment

### Prerequisites

- AWS Account ID
- AWS CLI configured with appropriate credentials
- GitHub repository secrets configured
- S3 bucket for Terraform state

### Manual Deployment

Each phase can be deployed independently:

```bash
# Phase 0: IAM
cd terraform/00-iam
terraform init
terraform apply

# Phase 1: Networking
cd terraform/01-networking
terraform init
terraform apply

# Phase 2: Kubernetes
cd terraform/02-kubernetes
terraform init
terraform apply
```

### Automated Deployment via GitHub Actions

Trigger the `deploy-full-infrastructure` workflow with:
- **action**: `plan`, `apply`, or `destroy`
- **clusters_to_deploy**: `all`, `dev`, `stg`, `prd`, or `sdx`

## Environments

| Environment | Cluster | Subnet CIDR | Pods CIDR | Services CIDR |
|-------------|---------|-------------|-----------|---------------|
| Development | eks-dev | 10.10.0.0/19 | 10.11.0.0/16 | 10.12.0.0/16 |
| Staging | eks-stg | 10.13.0.0/19 | 10.14.0.0/16 | 10.15.0.0/16 |
| Production | eks-prd | 10.16.0.0/19 | 10.17.0.0/16 | 10.18.0.0/16 |
| Sandbox | eks-sdx | 10.19.0.0/19 | 10.20.0.0/16 | 10.21.0.0/16 |

## Features

- ✅ Centralized IAM management
- ✅ Reusable IAM Roles across phases
- ✅ Private EKS clusters with IRSA (IAM Roles for Service Accounts)
- ✅ AWS Load Balancer Controller support
- ✅ Selective cluster deployment
- ✅ Automated validation and security scanning
- ✅ Multi-AZ deployment for high availability

## State Management

Terraform state stored in S3:
- Bucket: `vschiavo-home-terraform-state`
- IAM prefix: `aws-landing-zone/iam/state`
- Networking prefix: `aws-landing-zone/networking/state`
- Kubernetes prefix: `aws-landing-zone/kubernetes/state`

## Network Architecture

- **VPC**: Shared VPC across all environments
- **Subnets**: Public and private subnets across 2 availability zones
- **NAT Gateway**: For private subnet internet access
- **Internet Gateway**: For public subnet internet access
- **VPC Endpoints**: For AWS services (S3, ECR, EC2, etc)

## Security

- Private EKS clusters (API endpoint not publicly accessible)
- IRSA (IAM Roles for Service Accounts) for pod-level permissions
- Security groups for network isolation
- VPC Flow Logs enabled
- Encryption at rest and in transit
- AWS Systems Manager Session Manager for secure access

## Compliance

- CIS AWS Foundations Benchmark aligned
- AWS Well-Architected Framework principles
- Cost optimization with right-sizing recommendations
- Automated compliance scanning via GitHub Actions
