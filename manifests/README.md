# Kubernetes Manifests for AWS EKS

This directory contains Kubernetes manifest files for infrastructure components on AWS EKS.

## AWS Load Balancer Controller

The AWS Load Balancer Controller manages Application Load Balancers (ALB) and Network Load Balancers (NLB) for Kubernetes Ingress resources.

### Installation

First, install the AWS Load Balancer Controller:

```bash
# Add Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-dev \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::ACCOUNT_ID:role/AWSLoadBalancerControllerRole"

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Alternative: NGINX Ingress Controller

If you prefer NGINX Ingress Controller (same as GCP), use the provided manifests:

- **File**: `eks-ingress-nginx-1.13.0-external.yaml`
- **Namespace**: `ingress-nginx`
- **IngressClass**: `nginx-external`
- **Service Type**: LoadBalancer (internet-facing)
- **Purpose**: Handles external/public traffic
- **Replicas**: 2 (with HPA: 2-5)

- **File**: `eks-ingress-nginx-1.13.0-internal.yaml`
- **Namespace**: `ingress-nginx-internal`
- **IngressClass**: `nginx-internal`
- **Service Type**: LoadBalancer (internal)
- **Annotation**: `service.beta.kubernetes.io/aws-load-balancer-internal: "true"`
- **Purpose**: Handles internal/private traffic within VPC
- **Replicas**: 1

## Deployment

### Deploy NGINX Ingress Controllers

```bash
# Get cluster credentials
aws eks update-kubeconfig --name eks-dev --region sa-east-1

# Create namespaces
kubectl create namespace ingress-nginx
kubectl create namespace ingress-nginx-internal

# Deploy external ingress
kubectl apply -f eks-ingress-nginx-1.13.0-external.yaml

# Deploy internal ingress
kubectl apply -f eks-ingress-nginx-1.13.0-internal.yaml

# Verify deployment
kubectl get pods -n ingress-nginx
kubectl get pods -n ingress-nginx-internal

kubectl get svc -n ingress-nginx
kubectl get svc -n ingress-nginx-internal
```

## Usage Examples

### Option 1: AWS Load Balancer Controller (ALB)

#### External Ingress (Internet-facing ALB)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-external
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:sa-east-1:ACCOUNT:certificate/CERT_ID
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

#### Internal Ingress (Private ALB)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-internal
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  rules:
  - host: app.internal.example.com
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

### Option 2: NGINX Ingress Controller

#### External Ingress (Public Traffic)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-external
  annotations:
    kubernetes.io/ingress.class: nginx-external
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

#### Internal Ingress (Private Traffic)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-internal
  annotations:
    kubernetes.io/ingress.class: nginx-internal
spec:
  rules:
  - host: app.internal.example.com
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

## Key Differences: GCP vs AWS

### Load Balancer Annotations

| Feature | GCP (GKE) | AWS (EKS) |
|---------|-----------|-----------|
| **Internal LB** | `cloud.google.com/load-balancer-type: "Internal"` | `service.beta.kubernetes.io/aws-load-balancer-internal: "true"` or `alb.ingress.kubernetes.io/scheme: internal` |
| **External LB** | Default (no annotation) | `alb.ingress.kubernetes.io/scheme: internet-facing` |
| **Target Type** | N/A (automatic) | `alb.ingress.kubernetes.io/target-type: ip` |
| **SSL/TLS** | Managed via Ingress | `alb.ingress.kubernetes.io/certificate-arn` |

### Node Selectors

| GCP | AWS |
|-----|-----|
| `agentpool: ng-agent-01` | `agentpool: ng-general-01` or remove (EKS uses different label) |

## Components Deployed (NGINX)

Each NGINX ingress controller includes:
- ServiceAccounts and RBAC (ClusterRole, ClusterRoleBinding, Role, RoleBinding)
- ConfigMaps with optimized NGINX configuration
- Deployments with resource limits and health checks
- HorizontalPodAutoscaler (external only: 2-5 replicas)
- Services (LoadBalancer type - external or internal)
- IngressClass definitions
- Admission webhook jobs for validation
- PodDisruptionBudget (external only for high availability)
- ValidatingWebhookConfiguration for request validation

## Comparison: ALB vs NGINX

| Feature | AWS Load Balancer Controller (ALB) | NGINX Ingress Controller |
|---------|-----------------------------------|--------------------------|
| **Load Balancer** | AWS-managed ALB/NLB | NLB with NGINX pods |
| **Cost** | Pay per ALB + LCU | Pay for EC2 nodes only |
| **Features** | AWS WAF, Cognito, ACM integration | Advanced routing, auth |
| **Performance** | AWS-managed, highly scalable | Depends on pod resources |
| **Management** | Fully managed by AWS | Self-managed pods |

## Recommendation

- **Use AWS Load Balancer Controller** for simpler setup and AWS service integration
- **Use NGINX Ingress Controller** for advanced features, consistency with GCP, or complex routing needs
