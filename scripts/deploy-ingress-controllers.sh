#!/bin/bash

# ==============================================================================
# DEPLOY NGINX INGRESS CONTROLLERS TO EKS CLUSTER
# ==============================================================================

set -e

CLUSTER_NAME=${1:-"eks-dev"}
AWS_REGION=${2:-${AWS_DEFAULT_REGION:-"sa-east-1"}}

# Find the repository root (where manifests directory is located)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================="
echo "Deploying NGINX Ingress Controllers"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo "Repository root: $REPO_ROOT"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Update kubeconfig
echo "1. Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

# Wait for cluster to be ready
echo "2. Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Create namespaces
echo "3. Creating namespaces..."
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ingress-nginx-internal --dry-run=client -o yaml | kubectl apply -f -

# Cleanup existing jobs to avoid AlreadyExists errors
echo "3.5. Cleaning up existing admission jobs..."
kubectl delete job ingress-nginx-admission-create ingress-nginx-admission-patch -n ingress-nginx --ignore-not-found=true 2>/dev/null || true
kubectl delete job ingress-nginx-internal-admission-create ingress-nginx-internal-admission-patch -n ingress-nginx-internal --ignore-not-found=true 2>/dev/null || true

# Deploy external ingress
echo "4. Deploying external NGINX Ingress Controller..."
kubectl apply -f "$REPO_ROOT/manifests/eks-ingress-nginx-1.13.0-external.yaml"

# Deploy internal ingress
echo "5. Deploying internal NGINX Ingress Controller..."
kubectl apply -f "$REPO_ROOT/manifests/eks-ingress-nginx-1.13.0-internal.yaml"

# Wait for deployments
echo "6. Waiting for deployments to be ready (timeout: 10 minutes)..."

# Check pods status first
echo "6.1. Checking external ingress pods..."
kubectl get pods -n ingress-nginx

echo "6.2. Checking internal ingress pods..."
kubectl get pods -n ingress-nginx-internal

# Wait for deployments with increased timeout
echo "6.3. Waiting for external ingress deployment..."
kubectl wait --for=condition=available --timeout=600s \
  deployment/ingress-nginx-controller -n ingress-nginx || {
    echo "⚠️  External ingress deployment failed to become ready. Checking logs..."
    kubectl describe deployment ingress-nginx-controller -n ingress-nginx
    kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
    exit 1
  }

echo "6.4. Waiting for internal ingress deployment..."
kubectl wait --for=condition=available --timeout=600s \
  deployment/ingress-nginx-internal-controller -n ingress-nginx-internal || {
    echo "⚠️  Internal ingress deployment failed to become ready. Checking logs..."
    kubectl describe deployment ingress-nginx-internal-controller -n ingress-nginx-internal
    kubectl logs -n ingress-nginx-internal -l app.kubernetes.io/component=controller --tail=50
    exit 1
  }

# Get LoadBalancer IPs
echo ""
echo "=========================================="
echo -e "${GREEN}✓ NGINX Ingress Controllers deployed!${NC}"
echo "=========================================="
echo ""
echo "External LoadBalancer:"
kubectl get svc ingress-nginx-controller -n ingress-nginx

echo ""
echo "Internal LoadBalancer:"
kubectl get svc ingress-nginx-internal-controller -n ingress-nginx-internal

echo ""
echo "To get LoadBalancer hostnames:"
echo "  External: kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo "  Internal: kubectl get svc ingress-nginx-internal-controller -n ingress-nginx-internal -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
