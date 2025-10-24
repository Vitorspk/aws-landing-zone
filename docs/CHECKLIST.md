# AWS Landing Zone - Deployment Checklist

Use this checklist to ensure all prerequisites are met and deployment steps are completed successfully.

## Pre-Deployment

### AWS Account Setup
- [ ] AWS Account created and accessible
- [ ] AWS CLI installed (version 2.x recommended)
- [ ] AWS credentials configured (`aws configure`)
- [ ] Appropriate IAM permissions verified
- [ ] AWS region selected (default: sa-east-1)

### Tools Installation
- [ ] Terraform >= 1.5.0 installed
- [ ] kubectl installed
- [ ] git installed
- [ ] jq installed (for JSON parsing in scripts)

### Repository Setup
- [ ] Repository cloned locally
- [ ] All scripts are executable (`chmod +x scripts/*.sh`)
- [ ] `.gitignore` configured properly

### S3 Backend Setup
- [ ] S3 bucket created for Terraform state
  ```bash
  aws s3 mb s3://vschiavo-home-terraform-state --region sa-east-1
  ```
- [ ] Bucket versioning enabled
  ```bash
  aws s3api put-bucket-versioning \
    --bucket vschiavo-home-terraform-state \
    --versioning-configuration Status=Enabled
  ```
- [ ] Bucket encryption enabled
  ```bash
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

### DynamoDB Setup
- [ ] DynamoDB table created for state locking
  ```bash
  aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region sa-east-1
  ```

### Configuration Review
- [ ] Review and update variables in `terraform/00-iam/variables.tf`
- [ ] Review and update variables in `terraform/01-networking/variables.tf`
- [ ] Review and update variables in `terraform/02-kubernetes/variables.tf`
- [ ] Verify S3 bucket name in all `backend.tf` files
- [ ] Verify AWS region in all configuration files

### Pre-Deployment Check
- [ ] Run pre-deployment check script
  ```bash
  ./scripts/pre-deployment-check.sh
  ```

## Phase 0: IAM Deployment

- [ ] Navigate to IAM directory
  ```bash
  cd terraform/00-iam
  ```
- [ ] Initialize Terraform
  ```bash
  terraform init
  ```
- [ ] Verify initialization successful
- [ ] Format code
  ```bash
  terraform fmt -recursive
  ```
- [ ] Validate configuration
  ```bash
  terraform validate
  ```
- [ ] Review execution plan
  ```bash
  terraform plan
  ```
- [ ] Verify resources to be created:
  - [ ] 4 EKS cluster IAM roles (dev, stg, prd, sdx)
  - [ ] 4 EKS node group IAM roles (dev, stg, prd, sdx)
  - [ ] AWS Load Balancer Controller policy
  - [ ] EBS CSI Driver policy
- [ ] Apply configuration
  ```bash
  terraform apply
  ```
- [ ] Verify outputs
  ```bash
  terraform output
  ```
- [ ] Return to root directory
  ```bash
  cd ../..
  ```

## Phase 1: Networking Deployment

- [ ] Navigate to Networking directory
  ```bash
  cd terraform/01-networking
  ```
- [ ] Initialize Terraform
  ```bash
  terraform init
  ```
- [ ] Verify initialization successful
- [ ] Format code
  ```bash
  terraform fmt -recursive
  ```
- [ ] Validate configuration
  ```bash
  terraform validate
  ```
- [ ] Review execution plan
  ```bash
  terraform plan
  ```
- [ ] Verify resources to be created:
  - [ ] VPC (10.0.0.0/8)
  - [ ] 2 Public subnets (one per AZ)
  - [ ] 8 Private subnets (2 per environment)
  - [ ] Internet Gateway
  - [ ] 2 NAT Gateways with Elastic IPs
  - [ ] Route Tables
  - [ ] 8 Security Groups (4 cluster + 4 nodes)
  - [ ] 4 VPC Endpoints (S3, ECR API, ECR DKR, EC2, STS)
  - [ ] VPC Flow Logs
- [ ] Apply configuration (may take 5-10 minutes)
  ```bash
  terraform apply
  ```
- [ ] Verify outputs
  ```bash
  terraform output
  ```
- [ ] Test VPC connectivity
- [ ] Verify NAT Gateway IPs are allocated
- [ ] Return to root directory
  ```bash
  cd ../..
  ```

## Phase 2: Kubernetes Deployment

- [ ] Navigate to Kubernetes directory
  ```bash
  cd terraform/02-kubernetes
  ```
- [ ] Initialize Terraform
  ```bash
  terraform init
  ```
- [ ] Verify initialization successful
- [ ] Format code
  ```bash
  terraform fmt -recursive
  ```
- [ ] Validate configuration
  ```bash
  terraform validate
  ```
- [ ] Review execution plan
  ```bash
  terraform plan
  ```
- [ ] Verify resources to be created:
  - [ ] 4 EKS clusters (dev, stg, prd, sdx)
  - [ ] 4 Node groups
  - [ ] 4 OIDC providers for IRSA
  - [ ] EKS addons (VPC CNI, CoreDNS, Kube-proxy, EBS CSI)
  - [ ] CloudWatch log groups
- [ ] Apply configuration (may take 15-20 minutes per cluster)
  ```bash
  terraform apply
  ```
- [ ] Verify outputs
  ```bash
  terraform output
  ```
- [ ] Return to root directory
  ```bash
  cd ../..
  ```

## Post-Deployment Verification

### EKS Clusters

#### Dev Cluster
- [ ] Configure kubectl for dev cluster
  ```bash
  aws eks update-kubeconfig --name eks-dev --region sa-east-1
  ```
- [ ] Verify cluster access
  ```bash
  kubectl cluster-info
  ```
- [ ] Check nodes
  ```bash
  kubectl get nodes
  ```
- [ ] Verify nodes are Ready
- [ ] Check system pods
  ```bash
  kubectl get pods -n kube-system
  ```
- [ ] Verify all pods are Running

#### Stg Cluster
- [ ] Configure kubectl for stg cluster
  ```bash
  aws eks update-kubeconfig --name eks-stg --region sa-east-1
  ```
- [ ] Verify cluster access
- [ ] Check nodes
- [ ] Check system pods

#### Prd Cluster
- [ ] Configure kubectl for prd cluster
  ```bash
  aws eks update-kubeconfig --name eks-prd --region sa-east-1
  ```
- [ ] Verify cluster access
- [ ] Check nodes
- [ ] Check system pods

#### Sdx Cluster
- [ ] Configure kubectl for sdx cluster
  ```bash
  aws eks update-kubeconfig --name eks-sdx --region sa-east-1
  ```
- [ ] Verify cluster access
- [ ] Check nodes
- [ ] Check system pods

### Networking Verification

- [ ] Verify VPC created
  ```bash
  aws ec2 describe-vpcs --filters "Name=tag:Name,Values=shared-vpc"
  ```
- [ ] Verify subnets created
  ```bash
  aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"
  ```
- [ ] Verify NAT Gateways are available
  ```bash
  aws ec2 describe-nat-gateways
  ```
- [ ] Verify Internet Gateway attached
  ```bash
  aws ec2 describe-internet-gateways
  ```
- [ ] Test internet connectivity from private subnet (deploy test pod)

### IAM Verification

- [ ] Verify EKS cluster roles created
  ```bash
  aws iam list-roles --query 'Roles[?starts_with(RoleName, `eks-`) == `true`]'
  ```
- [ ] Verify policies attached correctly
- [ ] Test IRSA functionality (deploy pod with IAM role)

## Optional Components

### AWS Load Balancer Controller
- [ ] Create IAM role for service account
- [ ] Install AWS Load Balancer Controller via Helm
- [ ] Verify controller pods running
- [ ] Test with sample ingress

### Cluster Autoscaler
- [ ] Create IAM role for service account
- [ ] Deploy Cluster Autoscaler
- [ ] Configure autoscaling policies
- [ ] Test scaling behavior

### Monitoring
- [ ] Enable Container Insights
- [ ] Deploy Prometheus (optional)
- [ ] Deploy Grafana (optional)
- [ ] Configure CloudWatch dashboards

### Backup
- [ ] Configure EBS snapshot lifecycle
- [ ] Set up backup procedures
- [ ] Document restore process

## Security Hardening

- [ ] Review security group rules
- [ ] Enable GuardDuty
- [ ] Enable AWS Config
- [ ] Enable CloudTrail
- [ ] Configure IAM password policy
- [ ] Enable MFA for root account
- [ ] Review IAM policies for least privilege
- [ ] Enable AWS Security Hub
- [ ] Configure VPC Flow Logs analysis

## Documentation

- [ ] Document any customizations made
- [ ] Update architecture diagrams if modified
- [ ] Document access procedures
- [ ] Create runbooks for common operations
- [ ] Document troubleshooting procedures

## GitHub Setup (Optional)

- [ ] Create GitHub repository secrets:
  - [ ] `AWS_ACCESS_KEY_ID`
  - [ ] `AWS_SECRET_ACCESS_KEY`
- [ ] Test GitHub Actions workflows
- [ ] Verify automated deployments work

## Handoff

- [ ] Provide access to relevant team members
- [ ] Conduct walkthrough of infrastructure
- [ ] Share documentation
- [ ] Provide emergency contacts
- [ ] Schedule knowledge transfer sessions

## Sign-off

- [ ] Infrastructure deployment completed
- [ ] All verification tests passed
- [ ] Documentation completed
- [ ] Team trained
- [ ] Production ready

---

**Deployment Date:** _________________

**Deployed By:** _________________

**Reviewed By:** _________________

**Approved By:** _________________
