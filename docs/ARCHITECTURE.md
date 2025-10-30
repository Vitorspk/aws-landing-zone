# AWS Landing Zone - Architecture Overview

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Account                             │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                     VPC (10.0.0.0/8)                       │ │
│  │                                                            │ │
│  │  ┌──────────────────────────┐  ┌──────────────────────────┐│ │
│  │  │  Availability Zone A     │  │  Availability Zone B     ││ │
│  │  │                          │  │                          ││ │
│  │  │  ┌────────────────────┐  │  │  ┌────────────────────┐  ││ │
│  │  │  │   Public Subnet    │  │  │  │   Public Subnet    │  ││ │
│  │  │  │   10.0.0.0/24      │  │  │  │   10.0.1.0/24      │  ││ │
│  │  │  │                    │  │  │  │                    │  ││ │
│  │  │  │  ┌──────────────┐  │  │  │  │  ┌──────────────┐  │  ││ │
│  │  │  │  │ NAT Gateway  │  │  │  │  │  │ NAT Gateway  │  │  ││ │
│  │  │  │  └──────────────┘  │  │  │  │  └──────────────┘  │  ││ │
│  │  │  └────────────────────┘  │  │  └────────────────────┘  ││ │
│  │  │                          │  │                          ││ │
│  │  │  ┌────────────────────┐  │  │  ┌────────────────────┐  ││ │
│  │  │  │ Private Subnet DEV │  │  │  │ Private Subnet DEV │  ││ │
│  │  │  │ 10.10.0.0/19       │  │  │  │ 10.10.32.0/19      │  ││ │
│  │  │  │                    │  │  │  │                    │  ││ │
│  │  │  │  ┌──────────────┐  │  │  │  │  ┌──────────────┐  │  ││ │
│  │  │  │  │ EKS Nodes    │  │  │  │  │  │ EKS Nodes    │  │  ││ │
│  │  │  │  │ (dev)        │  │  │  │  │  │ (dev)        │  │  ││ │
│  │  │  │  └──────────────┘  │  │  │  │  └──────────────┘  │  ││ │
│  │  │  └────────────────────┘  │  │  └────────────────────┘  ││ │
│  │  │                          │  │                          ││ │
│  │  │  ┌────────────────────┐  │  │  ┌────────────────────┐  ││ │
│  │  │  │ Private Subnet STG │  │  │  │ Private Subnet STG │  ││ │
│  │  │  │ 10.13.0.0/19       │  │  │  │ 10.13.32.0/19      │  ││ │
│  │  │  └────────────────────┘  │  │  └────────────────────┘  ││ │
│  │  │                          │  │                          ││ │
│  │  │  ┌────────────────────┐  │  │  ┌────────────────────┐  ││ │
│  │  │  │ Private Subnet PRD │  │  │  │ Private Subnet PRD │  ││ │
│  │  │  │ 10.16.0.0/19       │  │  │  │ 10.16.32.0/19      │  ││ │
│  │  │  └────────────────────┘  │  │  └────────────────────┘  ││ │
│  │  │                          │  │                          ││ │
│  │  │  ┌────────────────────┐  │  │  ┌────────────────────┐  ││ │
│  │  │  │ Private Subnet SDX │  │  │  │ Private Subnet SDX │  ││ │
│  │  │  │ 10.19.0.0/19       │  │  │  │ 10.19.32.0/19      │  ││ │
│  │  │  └────────────────────┘  │  │  └────────────────────┘  ││ │
│  │  └──────────────────────────┘  └──────────────────────────┘│ │
│  │                                                            │ │
│  │  ┌────────────────────────────────────────────────────────┐│ │
│  │  │                    VPC Endpoints                       ││ │
│  │  │  • S3  • ECR  • EC2  • STS                             ││ │
│  │  └────────────────────────────────────────────────────────┘│ │
│  └──────────────────────────────────────────────────────────────┘
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                      IAM Roles                             │ │
│  │  • EKS Cluster Roles  • EKS Node Roles                     │ │
│  │  • IRSA Roles (AWS LB Controller, EBS CSI)                 │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    EKS Clusters                            │ │
│  │  • eks-dev  • eks-stg  • eks-prd  • eks-sdx                │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Phase 0: IAM

**Purpose:** Establish IAM roles and policies required for EKS clusters and AWS services.

**Resources Created:**
- **EKS Cluster Roles** (4): One per environment (dev, stg, prd, sdx)
  - Policies: `AmazonEKSClusterPolicy`, `AmazonEKSVPCResourceController`
  
- **EKS Node Group Roles** (4): One per environment
  - Policies: `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonSSMManagedInstanceCore`
  
- **AWS Load Balancer Controller Policy**: For ingress management
  
- **EBS CSI Driver Policy**: For persistent volume management

### Phase 1: Networking

**Purpose:** Create isolated network infrastructure with high availability.

**VPC Configuration:**
- **CIDR Block**: 10.0.0.0/8
- **DNS Support**: Enabled
- **DNS Hostnames**: Enabled

**Subnets:**

| Type | Environment | AZ-A CIDR | AZ-B CIDR | Purpose |
|------|-------------|-----------|-----------|---------|
| Public | Shared | 10.0.0.0/24 | 10.0.1.0/24 | NAT Gateways, Load Balancers |
| Private | DEV | 10.10.0.0/19 | 10.10.32.0/19 | EKS nodes, pods, services |
| Private | STG | 10.13.0.0/19 | 10.13.32.0/19 | EKS nodes, pods, services |
| Private | PRD | 10.16.0.0/19 | 10.16.32.0/19 | EKS nodes, pods, services |
| Private | SDX | 10.19.0.0/19 | 10.19.32.0/19 | EKS nodes, pods, services |

**Internet Gateway:**
- Provides internet access for public subnets
- Routes traffic to/from internet

**NAT Gateways:**
- **Count**: 2 (one per AZ for high availability)
- **Purpose**: Enable private subnet internet access
- **Elastic IPs**: Static IPs for outbound traffic

**Route Tables:**
- **Public Route Table**: Routes internet traffic via IGW
- **Private Route Tables**: Route internet traffic via NAT Gateway (one per AZ)

**Security Groups:**
- **EKS Cluster SG** (4): Control plane security groups
- **EKS Node SG** (4): Worker node security groups
- **VPC Endpoints SG**: For interface endpoints

**VPC Endpoints:**
- **S3** (Gateway): Free data transfer for S3 access
- **ECR API** (Interface): Pull container images
- **ECR DKR** (Interface): Docker registry operations
- **EC2** (Interface): EC2 API operations
- **STS** (Interface): IAM role assumption for IRSA

**VPC Flow Logs:**
- **Destination**: CloudWatch Logs
- **Traffic Type**: ALL
- **Retention**: 7 days

### Phase 2: Kubernetes (EKS)

**Purpose:** Deploy managed Kubernetes clusters for each environment.

**Cluster Configuration:**

| Environment | Cluster Name | Version | Node Type | Nodes (Min/Desired/Max) | Disk Size | Capacity Type |
|-------------|--------------|---------|-----------|-------------------------|-----------|---------------|
| Development | eks-dev | 1.34 | t3.medium | 1/2/4 | 50 GB | ON_DEMAND |
| Staging | eks-stg | 1.34 | t3.medium | 1/2/4 | 50 GB | ON_DEMAND |
| Production | eks-prd | 1.34 | t3.large | 2/3/6 | 100 GB | ON_DEMAND |
| Sandbox | eks-sdx | 1.34 | t3.small | 1/1/3 | 30 GB | SPOT |

**EKS Features:**
- **Endpoint Access**: Public + Private
- **Private Nodes**: All nodes in private subnets
- **Encryption**: Secrets encrypted at rest
- **Logging**: API, audit, authenticator, controller manager, scheduler

**OIDC Provider:**
- Enables IRSA (IAM Roles for Service Accounts)
- Pod-level IAM permissions
- Secure and granular access control

**EKS Addons:**
- **VPC CNI**: Network plugin for pod networking
- **CoreDNS**: DNS service discovery
- **Kube-proxy**: Network proxy
- **EBS CSI Driver**: Persistent volume provisioning

**Node Groups:**
- **Auto-scaling**: Automatic scaling based on demand
- **Multi-AZ**: Nodes distributed across availability zones
- **IMDSv2**: Enforced for enhanced security
- **SSM Access**: Session Manager for secure node access

## Network Flow

### Internet-bound Traffic (Egress)
```
Pod → Node → Private Subnet → Route Table → NAT Gateway → Internet Gateway → Internet
```

### Inbound Traffic (Ingress)
```
Internet → Internet Gateway → Public Subnet → Load Balancer → EKS Service → Pod
```

### Pod-to-Pod Communication
```
Pod A → VPC CNI → Pod B (same or different node)
```

### Pod-to-AWS Services
```
Pod → VPC Endpoint → AWS Service (S3, ECR, etc.)
```

## Security Architecture

### Network Security
- **Private Subnets**: All EKS nodes run in private subnets
- **Security Groups**: Least-privilege access rules
- **NACLs**: Default allow (security groups provide sufficient control)
- **VPC Flow Logs**: Network traffic monitoring and auditing

### Compute Security
- **IRSA**: Pod-level IAM permissions (no node-level credentials)
- **IMDSv2**: Prevents SSRF attacks
- **Encrypted EBS**: Data at rest encryption
- **Secrets Encryption**: KMS encryption for Kubernetes secrets

### Access Control
- **IAM Roles**: Separate roles per environment
- **RBAC**: Kubernetes role-based access control
- **Private API Endpoint**: Optionally restrict API access
- **SSM Session Manager**: No SSH keys required

## High Availability

### Multi-AZ Deployment
- **NAT Gateways**: One per AZ (2 total)
- **Subnets**: Distributed across 2 AZs
- **EKS Nodes**: Spread across multiple AZs
- **Control Plane**: AWS-managed multi-AZ (automatic)

### Fault Tolerance
- **Node Auto-scaling**: Automatic replacement of failed nodes
- **Pod Disruption Budgets**: Ensure minimum availability during updates
- **Health Checks**: Automatic pod restart on failure

## Cost Optimization

### Development/Sandbox
- **Smaller Instances**: t3.small/medium for lower workloads
- **SPOT Instances**: SDX uses spot for cost savings
- **Lower Capacity**: Reduced min/max node counts

### Production
- **Right-sizing**: t3.large for production workload
- **Reserved Instances**: Consider for long-term savings
- **Auto-scaling**: Scale down during off-peak hours

### Network
- **VPC Endpoints**: Reduce NAT Gateway data transfer costs
- **Single NAT Gateway**: Option to use one NAT Gateway (less HA)

## Scalability

### Horizontal Scaling
- **Node Groups**: Auto-scale from 1 to 6 nodes per environment
- **Pod Scaling**: HPA (Horizontal Pod Autoscaler) supported
- **Cluster Autoscaler**: Automatic node provisioning

### Vertical Scaling
- **VPA**: Vertical Pod Autoscaler support
- **Instance Types**: Easy to change via Terraform variables

## Monitoring and Logging

### CloudWatch Integration
- **Control Plane Logs**: All EKS logs to CloudWatch
- **VPC Flow Logs**: Network traffic analysis
- **Container Insights**: Optional pod/node metrics

### Observability
- **Prometheus**: Can be deployed for metrics
- **Grafana**: Dashboard visualization
- **FluentBit**: Log aggregation and forwarding

## Compliance

### AWS Best Practices
- ✅ Well-Architected Framework principles
- ✅ CIS AWS Foundations Benchmark aligned
- ✅ Encryption at rest and in transit
- ✅ Least privilege access

### Kubernetes Best Practices
- ✅ Private nodes
- ✅ RBAC enabled
- ✅ Network policies support
- ✅ Pod security standards

## Disaster Recovery

### Backup Strategy
- **etcd Snapshots**: AWS-managed automatic backups
- **Persistent Volumes**: EBS snapshots
- **Configuration**: Terraform state in S3 with versioning

### Recovery
- **Infrastructure**: Redeploy via Terraform
- **Data**: Restore from EBS snapshots
- **Configurations**: Version-controlled in Git

## Migration from GCP

### Key Differences

| GCP | AWS | Notes |
|-----|-----|-------|
| GKE | EKS | Similar managed Kubernetes |
| Service Accounts | IAM Roles | IAM Roles for Service Accounts (IRSA) |
| Cloud NAT | NAT Gateway | Higher cost on AWS |
| VPC | VPC | Similar concepts |
| Workload Identity | IRSA | Pod-level IAM permissions |
| Cloud Armor | WAF | Different implementation |

### Equivalent Services
- **GCS** → **S3**: Object storage
- **Cloud SQL** → **RDS**: Managed databases
- **Memorystore** → **ElastiCache**: Managed Redis/Memcached
- **Cloud Build** → **CodeBuild**: CI/CD
- **Artifact Registry** → **ECR**: Container registry
