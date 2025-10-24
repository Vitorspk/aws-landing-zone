# AWS Landing Zone - Project Summary

## Overview

Complete AWS infrastructure automation for deploying a multi-environment Kubernetes platform using Terraform and GitHub Actions. This project provides a production-ready landing zone with:

- **4 EKS Clusters**: dev, stg, prd, sdx
- **Isolated Networking**: VPC with public/private subnets across 2 AZs
- **IAM Management**: Centralized roles and policies
- **High Availability**: Multi-AZ deployment
- **Security**: Private clusters, IRSA, VPC endpoints
- **Automation**: GitHub Actions workflows

## Project Structure

```
aws-landing-zone/
├── terraform/
│   ├── 00-iam/               # IAM roles and policies
│   │   ├── main.tf
│   │   ├── iam-roles.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── backend.tf
│   ├── 01-networking/        # VPC, subnets, security groups
│   │   ├── main.tf
│   │   ├── security-groups.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── backend.tf
│   └── 02-kubernetes/        # EKS clusters
│       ├── main.tf
│       ├── modules/
│       │   └── eks-cluster/
│       │       ├── main.tf
│       │       ├── variables.tf
│       │       └── outputs.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── backend.tf
├── .github/
│   └── workflows/
│       ├── validate.yml
│       └── deploy-full-infrastructure.yml
├── docs/
│   ├── DEPLOYMENT.md
│   ├── ARCHITECTURE.md
│   ├── CHECKLIST.md
│   ├── TROUBLESHOOTING.md
│   └── GCP-TO-AWS-MIGRATION.md
├── manifests/
│   ├── README.md
│   └── examples/
│       ├── nginx-deployment.yaml
│       └── test-pod-with-irsa.yaml
├── scripts/
│   ├── pre-deployment-check.sh
│   └── format-terraform.sh
├── README.md
├── Makefile
└── .gitignore
```

## Infrastructure Components

### Phase 0: IAM (Identity and Access Management)
- **EKS Cluster Roles**: 4 roles (one per environment)
- **EKS Node Group Roles**: 4 roles with EC2 and container registry permissions
- **AWS Load Balancer Controller Policy**: For ingress management
- **EBS CSI Driver Policy**: For persistent storage

### Phase 1: Networking
- **VPC**: 10.0.0.0/8 CIDR block
- **Public Subnets**: 2 subnets across 2 AZs (for NAT Gateways, load balancers)
- **Private Subnets**: 8 subnets (2 per environment x 4 environments)
- **Internet Gateway**: For public subnet internet access
- **NAT Gateways**: 2 NAT Gateways (one per AZ) for private subnet internet access
- **Security Groups**: 8 security groups (cluster + nodes per environment)
- **VPC Endpoints**: S3, ECR, EC2, STS for private AWS API access
- **VPC Flow Logs**: Network traffic auditing

### Phase 2: Kubernetes (EKS)
- **Development Cluster**: 2x t3.medium nodes (1-4 range)
- **Staging Cluster**: 2x t3.medium nodes (1-4 range)
- **Production Cluster**: 3x t3.large nodes (2-6 range)
- **Sandbox Cluster**: 1x t3.small SPOT instance (1-3 range)

Each cluster includes:
- OIDC provider for IRSA
- EKS addons (VPC CNI, CoreDNS, Kube-proxy, EBS CSI Driver)
- CloudWatch log groups
- Auto-scaling node groups

## Key Features

### Security
✅ All EKS nodes in private subnets
✅ IRSA for pod-level AWS API permissions
✅ Secrets encryption at rest
✅ VPC Flow Logs for audit
✅ IMDSv2 enforced on nodes
✅ Private VPC endpoints to reduce internet exposure

### High Availability
✅ Multi-AZ deployment (2 availability zones)
✅ Redundant NAT Gateways
✅ Auto-scaling node groups
✅ AWS-managed control plane (multi-AZ by default)

### Cost Optimization
✅ SPOT instances for sandbox environment
✅ Right-sized instances per environment
✅ VPC endpoints to reduce NAT Gateway costs
✅ Auto-scaling to match demand

### Automation
✅ GitHub Actions for CI/CD
✅ Terraform for Infrastructure as Code
✅ Automated validation on PRs
✅ Selective cluster deployment

## Quick Start

### Prerequisites
```bash
# Install required tools
brew install terraform awscli kubectl

# Configure AWS credentials
aws configure

# Clone repository
git clone <repository-url>
cd aws-landing-zone
```

### Deploy Infrastructure
```bash
# Run pre-deployment check
./scripts/pre-deployment-check.sh

# Deploy Phase 0: IAM
make init-iam
make apply-iam

# Deploy Phase 1: Networking
make init-networking
make apply-networking

# Deploy Phase 2: Kubernetes
make init-kubernetes
make apply-kubernetes
```

### Configure kubectl
```bash
# Dev cluster
aws eks update-kubeconfig --name eks-dev --region sa-east-1

# Verify access
kubectl get nodes
```

## Deployment Time

| Phase | Duration | Notes |
|-------|----------|-------|
| IAM | ~2 minutes | Fast, only IAM resources |
| Networking | ~5-10 minutes | NAT Gateways take longest |
| Kubernetes (per cluster) | ~15-20 minutes | Control plane creation |
| **Total (all 4 clusters)** | **~70-90 minutes** | Can deploy selectively |

## Estimated Monthly Costs

### Compute
- EKS Control Planes: 4 × $72 = **$288/month**
- EC2 Instances (dev/stg): 4 × t3.medium × $0.0416/hr = **~$120/month**
- EC2 Instances (prd): 3 × t3.large × $0.0832/hr = **~$180/month**
- EC2 Instances (sdx): 1 × t3.small SPOT × ~$0.01/hr = **~$7/month**

### Networking
- NAT Gateways: 2 × $0.045/hr = **~$65/month**
- NAT Gateway Data: Variable (est. **~$50/month**)
- Elastic IPs: 2 × $0.005/hr (if unused) = **~$7/month**

### Storage
- EBS Volumes: ~500GB × $0.08/GB = **~$40/month**

### **Total Estimated**: **~$750-850/month**

*Note: Actual costs vary based on usage, data transfer, and scaling*

## Comparison with GCP Landing Zone

| Feature | GCP | AWS |
|---------|-----|-----|
| Cluster Cost | Free (Standard GKE) | $72/month per cluster |
| Node Management | GKE Node Pools | EKS Node Groups |
| Pod Identity | Workload Identity | IRSA |
| Ingress | GCE Ingress | AWS LB Controller |
| NAT | Cloud NAT | NAT Gateway |
| State Backend | GCS | S3 + DynamoDB |

**Key Differences:**
- AWS EKS has control plane costs
- AWS NAT Gateway more expensive than Cloud NAT
- Both platforms offer similar Kubernetes features
- AWS IRSA vs GCP Workload Identity (similar functionality)

## Networking Details

### CIDR Allocation

| Environment | Private Subnet AZ-A | Private Subnet AZ-B |
|-------------|---------------------|---------------------|
| Public | 10.0.0.0/24 | 10.0.1.0/24 |
| DEV | 10.10.0.0/19 | 10.10.32.0/19 |
| STG | 10.13.0.0/19 | 10.13.32.0/19 |
| PRD | 10.16.0.0/19 | 10.16.32.0/19 |
| SDX | 10.19.0.0/19 | 10.19.32.0/19 |

### Network Flow

**Outbound (Pod → Internet):**
```
Pod → Node → Private Subnet → Route Table → NAT Gateway → IGW → Internet
```

**Inbound (Internet → Pod):**
```
Internet → IGW → ALB (Public Subnet) → EKS Service → Pod
```

## Maintenance

### Regular Tasks
- Monitor CloudWatch logs and metrics
- Review VPC Flow Logs for security
- Update EKS cluster versions (quarterly)
- Review and optimize costs monthly
- Update Terraform providers quarterly
- Rotate IAM credentials regularly

### Backup Strategy
- Terraform state in S3 (versioned)
- EKS etcd snapshots (AWS-managed)
- EBS volume snapshots (configure lifecycle)
- Git repository for configuration

## Troubleshooting

Common issues and solutions are documented in `docs/TROUBLESHOOTING.md`.

Quick checks:
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check cluster status
aws eks describe-cluster --name eks-dev --region sa-east-1

# View Terraform state
cd terraform/02-kubernetes
terraform state list

# Check node status
kubectl get nodes -o wide
```

## Documentation

- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)**: Step-by-step deployment guide
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)**: Detailed architecture overview
- **[CHECKLIST.md](docs/CHECKLIST.md)**: Deployment checklist
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**: Common issues and solutions
- **[GCP-TO-AWS-MIGRATION.md](docs/GCP-TO-AWS-MIGRATION.md)**: Migration guide from GCP

## Next Steps

After deployment:

1. **Configure kubectl** for all clusters
2. **Install AWS Load Balancer Controller** for ingress
3. **Set up monitoring** with CloudWatch Container Insights
4. **Deploy sample applications** from `manifests/examples/`
5. **Configure CI/CD pipelines** for application deployment
6. **Set up backup procedures** for persistent data
7. **Implement network policies** for pod-to-pod security
8. **Configure auto-scaling** policies
9. **Set up alerting** for critical metrics
10. **Document runbooks** for operations team

## Support and Contributing

### Getting Help
- Review documentation in `docs/` directory
- Check `docs/TROUBLESHOOTING.md` for common issues
- Open GitHub issue for bugs or feature requests

### Contributing
1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Submit pull request

### Standards
- Follow Terraform best practices
- Use consistent naming conventions
- Document all changes
- Run `terraform fmt` before committing
- Ensure `./scripts/pre-deployment-check.sh` passes

## License

[Specify your license here]

## Authors

- **Initial Development**: [Your Name]
- **Maintained by**: [Team Name]

## Acknowledgments

- Based on AWS EKS best practices
- Inspired by GCP Landing Zone architecture
- Terraform AWS provider community

---

**Project Status**: Production Ready ✅

**Last Updated**: 2025-10-23

**Version**: 1.0.0
