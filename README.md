# AWS Landing Zone

Complete AWS infrastructure automation using Terraform and GitHub Actions.

## ⚠️ Security Notice

**Before deploying this infrastructure, please ensure:**

1. 🔐 **Never commit `.tfvars` files with real values** - Use `terraform.tfvars.example` as a template
2. 🔑 **Always use GitHub Secrets for AWS credentials** - Never hardcode access keys
3. 🛡️ **Review IAM permissions before applying** - Follow the principle of least privilege
4. 📝 **Keep sensitive data out of version control** - Check `.gitignore` is properly configured
5. 🔄 **Use remote state storage** - Terraform state should be in S3, not committed to Git

For detailed security guidelines, see [SECURITY.md](docs/SECURITY.md).

---

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
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT.md
│   └── SECURITY.md      # Security best practices
└── .github/workflows/    # GitHub Actions
    ├── deploy-infrastructure.yml
    ├── deploy-ingress-nginx.yml
    ├── destroy-ingress-nginx.yml
    └── terraform-ci.yml
```

## Prerequisites

Before deploying, ensure you have:

- AWS Account with billing enabled
- AWS IAM user with required permissions
- GitHub repository secrets configured (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
- Terraform >= 1.5.0
- AWS CLI installed and configured

## Configuration

### 1. Copy the example configuration files:
```bash
cd terraform/00-iam
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS region

cd ../01-networking
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration

cd ../02-kubernetes
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your cluster preferences
```

### 2. Configure your variables in `terraform.tfvars`:
```hcl
region          = "sa-east-1"
deploy_clusters = "dev,stg"  # or "all"
```

### 3. Never commit `terraform.tfvars` to Git!
(already in `.gitignore`)

## Deployment

### Manual Deployment

Each phase can be deployed independently:

```bash
# Phase 0: IAM
cd terraform/00-iam
terraform init
terraform plan
terraform apply

# Phase 1: Networking
cd ../01-networking
terraform init
terraform plan
terraform apply

# Phase 2: Kubernetes
cd ../02-kubernetes
terraform init
terraform plan
terraform apply
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
```

### Automated Deployment via GitHub Actions

#### 1. Configure GitHub Secrets:
- Go to repository Settings → Secrets and variables → Actions
- Add secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_DEFAULT_REGION` (optional)

#### 2. Deploy Infrastructure (Core)

Trigger the `deploy-infrastructure` workflow with:
- **phase**: `all`, `iam`, `networking`, or `kubernetes`
- **action**: `init`, `plan`, or `apply`
- **clusters**: `all`, `dev`, `stg`, `prd`, `sdx`, or combinations

**Note**: This deploys ONLY the core infrastructure (IAM, Networking, EKS clusters).

#### 3. Deploy Ingress NGINX (After Infrastructure)

Trigger the `deploy-ingress-nginx` workflow with:
- **clusters**: `all`, `dev`, `stg`, `prd`, `sdx`, or combinations
- **ingress_type**: `both`, `external`, or `internal`
- **action**: `apply`, `delete`, or `status`
- **validate**: `true` or `false`

## Environments

VPC CIDR: `192.168.0.0/16`. Each environment gets a `/20` private-subnet allocation, split into two `/21`s across 2 availability zones.

| Environment | Cluster | Private Subnet CIDR (/20) |
|-------------|---------|---------------------------|
| Development | eks-dev | 192.168.0.0/20 |
| Staging | eks-stg | 192.168.16.0/20 |
| Production | eks-prd | 192.168.32.0/20 |
| Sandbox | eks-sdx | 192.168.48.0/20 |

Public subnets (shared across all environments, one per AZ): `192.168.192.0/20`, `192.168.208.0/20`.

## Features

- ✅ Centralized IAM management
- ✅ Reusable IAM Roles across phases
- ✅ EKS clusters with IRSA (IAM Roles for Service Accounts); API endpoint is public by default (configurable, see docs/ARCHITECTURE.md)
- ✅ NGINX Ingress Controllers (external + internal)
- ✅ Selective cluster deployment
- ✅ Automated validation and security scanning
- ✅ Multi-AZ deployment for high availability
- ✅ Flexible region configuration

## Configuration

### Region Configuration

The AWS region is **configurable** and not hardcoded. Set it via:

1. **GitHub Secrets** (for CI/CD): `AWS_DEFAULT_REGION`
2. **Terraform variables**: `-var="region=your-region"` or `terraform.tfvars`
3. **Environment variable**: `export AWS_DEFAULT_REGION=your-region`

Default region: `sa-east-1` (São Paulo)

### State Management

Terraform state stored in S3:
- Bucket: `<your-bucket>-terraform-state`
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

- EKS worker nodes in private subnets; the API endpoint itself is public by default so CI can reach it, with `public_access_cidrs` configurable per cluster if you need to restrict it
- IRSA (IAM Roles for Service Accounts) for pod-level permissions
- Security groups for network isolation
- VPC Flow Logs enabled
- Encryption at rest and in transit
- AWS Systems Manager Session Manager for secure access

## NGINX Ingress Controllers

NGINX Ingress Controllers are deployed using a **dedicated workflow** (`deploy-ingress-nginx`):

- **External Ingress** (`nginx`):
  - Namespace: `ingress-nginx-external`
  - IngressClass: `nginx`
  - LoadBalancer: Internet-facing NLB
  - Use for: Public-facing applications

- **Internal Ingress** (`nginx-internal`):
  - Namespace: `ingress-nginx-internal`
  - IngressClass: `nginx-internal`
  - LoadBalancer: Internal NLB (VPC only)
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
kubectl apply -f manifests/eks-ingress-nginx-1.13.3-external.yaml
kubectl apply -f manifests/eks-ingress-nginx-1.13.3-internal.yaml
```

### Usage Example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx  # For external (public)
  # ingressClassName: nginx-internal  # For internal (private)
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

## Documentation

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Architecture overview
- [DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deployment guide
- [SECURITY.md](docs/SECURITY.md) - Security best practices
- [GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md) - GitHub Secrets configuration

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

Open a PR against `master` — CI (`terraform-ci.yml`) and the automated Claude Code review must pass before merging.

## Compliance

- CIS AWS Foundations Benchmark aligned
- AWS Well-Architected Framework principles
- Cost optimization with right-sizing recommendations
- Automated compliance scanning via GitHub Actions

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
