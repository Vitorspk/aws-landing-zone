# Kubernetes Manifests

This directory contains Kubernetes manifests for deploying applications and services to the EKS clusters.

## Directory Structure

```
manifests/
├── README.md                          # This file
├── aws-load-balancer-controller/      # AWS Load Balancer Controller
├── examples/                          # Example applications
│   ├── nginx-deployment.yaml
│   ├── sample-app-with-ingress.yaml
│   └── test-pod-with-irsa.yaml
└── monitoring/                        # Monitoring stack (optional)
```

## Prerequisites

Before applying these manifests, ensure:

1. EKS cluster is running and accessible
2. kubectl is configured: `aws eks update-kubeconfig --name eks-dev --region sa-east-1`
3. Required IAM roles are created (from Phase 0)

## AWS Load Balancer Controller

The AWS Load Balancer Controller manages Elastic Load Balancers for Kubernetes services and ingresses.

### Installation

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
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::ACCOUNT_ID:role/AmazonEKSLoadBalancerControllerRole
```

## Examples

### Deploy NGINX

```bash
kubectl apply -f examples/nginx-deployment.yaml
```

### Deploy Sample App with Ingress

```bash
kubectl apply -f examples/sample-app-with-ingress.yaml
```

## IRSA (IAM Roles for Service Accounts)

Service accounts can assume IAM roles for AWS API access.

### Example: S3 Access

1. Create IAM role with S3 permissions
2. Add trust relationship for OIDC provider
3. Annotate service account:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/S3ReaderRole
```

4. Use service account in pod spec:

```yaml
spec:
  serviceAccountName: s3-reader
  containers:
  - name: app
    image: my-app:latest
```

## Monitoring

Optional monitoring stack with Prometheus and Grafana can be deployed:

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace
```

## Best Practices

1. **Namespaces**: Use namespaces to isolate workloads
2. **Resource Limits**: Always set resource requests and limits
3. **Health Checks**: Configure liveness and readiness probes
4. **Labels**: Use consistent labeling for better organization
5. **Secrets**: Use AWS Secrets Manager or Kubernetes secrets (encrypted)
6. **Network Policies**: Implement network policies for security
7. **Pod Security**: Use Pod Security Standards

## Useful Commands

```bash
# Get all resources
kubectl get all -A

# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# View logs
kubectl logs <pod-name> -n <namespace> -f

# Execute command in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Port forward
kubectl port-forward svc/<service-name> 8080:80 -n <namespace>

# Apply manifest
kubectl apply -f manifest.yaml

# Delete resources
kubectl delete -f manifest.yaml
```
