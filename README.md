# AWS Landing Zone

Complete AWS infrastructure automation using Terraform and GitHub Actions.

## Quick Start

### 1. Deploy Core Infrastructure
```
GitHub Actions → deploy-infrastructure
  phase: all
  action: apply
  clusters: all
⏱️ ~25 minutes
```

### 2. Deploy Ingress NGINX
```
GitHub Actions → deploy-ingress-nginx
  clusters: all
  ingress_type: both
  action: apply
  validate: true
⏱️ ~5 minutes per cluster
```

### 3. Access Your Clusters
```bash
aws eks update-kubeconfig --name <YOUR_CLUSTER_NAME> --region <YOUR_AWS_REGION>
kubectl get nodes
```

### 4. Verify Ingress
```
GitHub Actions → deploy-ingress-nginx
  action: status
```

---

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
├── manifests/            # Kubernetes manifests (Ingress NGINX)
├── scripts/              # Utility scripts
├── docs/                 # Documentation
│   ├── INGRESS-NGINX-ARCHITECTURE.md
│   └── INGRESS-NGINX-IMPLEMENTATION.md
└── .github/workflows/    # GitHub Actions
    ├── deploy-infrastructure.yml    # Core infrastructure
    ├── deploy-ingress-nginx.yml     # Ingress deployment
    ├── destroy-ingress-nginx.yml    # Ingress cleanup
    └── terraform-ci.yml             # CI/CD validation
```

## GitHub Actions Workflows

### Infrastructure Workflows

1. **deploy-infrastructure.yml** - Deploy core infrastructure
   - IAM (Phase 0)
   - Networking (Phase 1)
   - Kubernetes/EKS (Phase 2)
   - Does NOT deploy Ingress NGINX

2. **destroy-infrastructure.yml** - Destroy infrastructure
   - Tear down all infrastructure resources
   - Multi-phase destruction

### Ingress NGINX Workflows

3. **deploy-ingress-nginx.yml** - Deploy/manage Ingress NGINX
   - Deploy External and/or Internal Ingress
   - Multi-cluster support
   - Automatic validation
   - Actions: apply, delete, status

4. **destroy-ingress-nginx.yml** - Cleanup Ingress NGINX
   - Remove Ingress from specific clusters
   - Requires explicit confirmation
   - Complete cleanup including stuck resources

### CI/CD Workflows

5. **terraform-ci.yml** - Terraform validation and security scanning
   - Runs on pull requests
   - Validates syntax and formatting
   - Security scanning with tfsec

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
terraform apply -var="region=sa-east-1"

# Phase 1: Networking
cd terraform/01-networking
terraform init
terraform apply -var="region=sa-east-1"

# Phase 2: Kubernetes - All clusters
cd terraform/02-kubernetes
terraform init
terraform apply -var="region=sa-east-1"

# Or deploy specific clusters only:
terraform apply -var="region=sa-east-1" -var="deploy_clusters=dev"
terraform apply -var="region=sa-east-1" -var="deploy_clusters=dev,stg"
terraform apply -var="region=sa-east-1" -var="deploy_clusters=prd"
```

### Selective Cluster Deployment

You can choose which clusters to deploy using the `deploy_clusters` variable:

```bash
# Deploy only DEV cluster (~15-20 min, ~$220/month)
terraform apply -var="region=sa-east-1" -var="deploy_clusters=dev"

# Deploy DEV + STG (~30-40 min, ~$360/month)
terraform apply -var="region=sa-east-1" -var="deploy_clusters=dev,stg"

# Deploy DEV + STG + PRD (~50-60 min, ~$620/month)
terraform apply -var="region=sa-east-1" -var="deploy_clusters=dev,stg,prd"

# Deploy all clusters (~70-80 min, ~$750-850/month)
terraform apply -var="region=sa-east-1" -var="deploy_clusters=all"
# Or simply (all is the default):
terraform apply -var="region=sa-east-1"

# Deploy only production
terraform apply -var="region=sa-east-1" -var="deploy_clusters=prd"

# Deploy only sandbox for testing
terraform apply -var="region=sa-east-1" -var="deploy_clusters=sdx"
```

### Automated Deployment via GitHub Actions

#### 1. Deploy Infrastructure (Core)

Trigger the `deploy-infrastructure` workflow with:
- **phase**: `all`, `iam`, `networking`, or `kubernetes`
- **action**: `init`, `plan`, or `apply`
- **clusters**: `all`, `dev`, `stg`, `prd`, `sdx`, or combinations like `dev,stg`

**Note**: This deploys ONLY the core infrastructure (IAM, Networking, EKS clusters). Ingress NGINX is now deployed separately.

#### 2. Deploy Ingress NGINX (After Infrastructure)

Trigger the `deploy-ingress-nginx` workflow with:
- **clusters**: `all`, `dev`, `stg`, `prd`, `sdx`, or combinations
- **ingress_type**: `both`, `external`, or `internal`
- **action**: `apply`, `delete`, or `status`
- **validate**: `true` or `false` (automatic validation after deploy)

This workflow is **separate** from infrastructure deployment, allowing you to:
- Deploy/update Ingress independently (~5 min vs 30 min for full infra)
- Choose specific clusters and ingress types
- Quickly rollback or update Ingress versions

### Post-Deployment: Access Clusters

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
- ✅ NGINX Ingress Controllers (external + internal) auto-deployed
- ✅ Selective cluster deployment (dev, stg, prd, sdx, or any combination)
- ✅ Automated validation and security scanning
- ✅ Multi-AZ deployment for high availability
- ✅ Flexible region configuration via variables

## Configuration

### Region Configuration

The AWS region is **configurable** and not hardcoded. You can set it in three ways:

1. **GitHub Secrets** (for CI/CD): Set `AWS_DEFAULT_REGION` secret
2. **Terraform variables**: Pass `-var="region=your-region"` or create `terraform.tfvars`
3. **Environment variable**: Export `AWS_DEFAULT_REGION=your-region`

Default region: `sa-east-1` (São Paulo)

### State Management

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

## NGINX Ingress Controllers

NGINX Ingress Controllers are deployed using a **dedicated workflow** (`deploy-ingress-nginx`):

- **External Ingress** (`nginx-external`):
  - Namespace: `ingress-nginx`
  - LoadBalancer: Internet-facing NLB
  - Replicas: 2 (with HPA: 2-5)
  - Use for: Public-facing applications

- **Internal Ingress** (`nginx-internal`):
  - Namespace: `ingress-nginx-internal`
  - LoadBalancer: Internal NLB (VPC only)
  - Replicas: 1
  - Use for: Internal/private applications

### Deploy Ingress NGINX

**Via GitHub Actions:**
```
Workflow: deploy-ingress-nginx
Inputs:
  - clusters: all (or specific: dev, stg, prd, sdx)
  - ingress_type: both (or external, internal)
  - action: apply
  - validate: true
```

**Via kubectl (manual):**
```bash
# Connect to cluster
aws eks update-kubeconfig --name <YOUR_CLUSTER_NAME> --region <YOUR_AWS_REGION>

# Apply manifests
kubectl apply -f manifests/eks-ingress-nginx-1.13.0-external.yaml
kubectl apply -f manifests/eks-ingress-nginx-1.13.0-internal.yaml
```

### Verify Installation

**Via GitHub Actions:**
```
Workflow: deploy-ingress-nginx
Inputs:
  - action: status
```

**Via kubectl:**
```bash
# Check external ingress
kubectl get pods -n ingress-nginx
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Check internal ingress
kubectl get pods -n ingress-nginx-internal
kubectl get svc ingress-nginx-internal-controller -n ingress-nginx-internal
```

### Update or Destroy Ingress

**Update:**
```
Workflow: deploy-ingress-nginx
Inputs:
  - clusters: all
  - ingress_type: both
  - action: apply
```

**Destroy:**
```
Workflow: destroy-ingress-nginx
Inputs:
  - clusters: dev (or all, stg, prd, sdx)
  - ingress_type: both
  - confirm: yes (REQUIRED)
```

### Usage Example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    kubernetes.io/ingress.class: nginx-external  # or nginx-internal
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

## Compliance

- CIS AWS Foundations Benchmark aligned
- AWS Well-Architected Framework principles
- Cost optimization with right-sizing recommendations
- Automated compliance scanning via GitHub Actions
