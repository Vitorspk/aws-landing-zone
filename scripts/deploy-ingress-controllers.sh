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

# Deploy external ingress
echo "4. Deploying external NGINX Ingress Controller..."
kubectl apply -f "$REPO_ROOT/manifests/eks-ingress-nginx-1.13.0-external.yaml"

# Deploy internal ingress
echo "5. Deploying internal NGINX Ingress Controller..."
kubectl apply -f "$REPO_ROOT/manifests/eks-ingress-nginx-1.13.0-internal.yaml"

# Wait for deployments
echo "6. Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/ingress-nginx-controller -n ingress-nginx

kubectl wait --for=condition=available --timeout=300s \
  deployment/ingress-nginx-internal-controller -n ingress-nginx-internal

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
