#!/bin/bash

# ==============================================================================
# DEPLOY NGINX INGRESS CONTROLLERS TO EKS CLUSTER
# ==============================================================================

# Remove set -e to allow controlled error handling
set -o pipefail

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
RED='\033[0;31m'
NC='\033[0m'

# Exit codes
EXIT_SUCCESS=0
EXIT_TIMEOUT=100  # Non-critical timeout
EXIT_CRITICAL=1   # Critical failure

# Helper function for critical errors
fail_critical() {
    echo -e "${RED}❌ CRITICAL ERROR: $1${NC}"
    exit $EXIT_CRITICAL
}

# Helper function for timeout warnings
warn_timeout() {
    echo -e "${YELLOW}⚠️  TIMEOUT WARNING: $1${NC}"
    echo -e "${YELLOW}NGINX deployment was initiated but did not complete in time.${NC}"
    echo -e "${YELLOW}The deployment will continue in the background.${NC}"
    exit $EXIT_TIMEOUT
}

# Update kubeconfig
echo "1. Updating kubeconfig..."
if ! aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"; then
    fail_critical "Failed to update kubeconfig. Cluster may not exist or credentials are invalid."
fi

# Verify kubectl works
if ! kubectl cluster-info &>/dev/null; then
    fail_critical "Cannot connect to cluster. Check cluster status and credentials."
fi

# Wait for cluster to be ready
echo "2. Waiting for cluster to be ready..."
if ! kubectl wait --for=condition=Ready nodes --all --timeout=300s; then
    fail_critical "Cluster nodes are not ready. Check cluster and node group status."
fi

# Create namespaces
echo "3. Creating namespaces..."
if ! kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -; then
    fail_critical "Failed to create ingress-nginx namespace."
fi

if ! kubectl create namespace ingress-nginx-internal --dry-run=client -o yaml | kubectl apply -f -; then
    fail_critical "Failed to create ingress-nginx-internal namespace."
fi

# Cleanup existing jobs to avoid AlreadyExists errors
echo "3.5. Cleaning up existing admission jobs..."
kubectl delete job ingress-nginx-admission-create ingress-nginx-admission-patch -n ingress-nginx --ignore-not-found=true 2>/dev/null || true
kubectl delete job ingress-nginx-internal-admission-create ingress-nginx-internal-admission-patch -n ingress-nginx-internal --ignore-not-found=true 2>/dev/null || true

# Deploy external ingress
echo "4. Deploying external NGINX Ingress Controller..."
if [ ! -f "$REPO_ROOT/manifests/eks-ingress-nginx-1.13.0-external.yaml" ]; then
    fail_critical "Manifest file not found: $REPO_ROOT/manifests/eks-ingress-nginx-1.13.0-external.yaml"
fi

if ! kubectl apply -f "$REPO_ROOT/manifests/eks-ingress-nginx-1.13.0-external.yaml"; then
    fail_critical "Failed to apply external NGINX manifest."
fi

# Deploy internal ingress
echo "5. Deploying internal NGINX Ingress Controller..."
if [ ! -f "$REPO_ROOT/manifests/eks-ingress-nginx-1.13.0-internal.yaml" ]; then
    fail_critical "Manifest file not found: $REPO_ROOT/manifests/eks-ingress-nginx-1.13.0-internal.yaml"
fi

if ! kubectl apply -f "$REPO_ROOT/manifests/eks-ingress-nginx-1.13.0-internal.yaml"; then
    fail_critical "Failed to apply internal NGINX manifest."
fi

# CRITICAL: Wait for admission webhook jobs to complete BEFORE waiting for deployments
echo "5.5. Waiting for admission webhook jobs to complete..."
echo "5.5.1. Waiting for external admission jobs..."
if ! kubectl wait --for=condition=complete --timeout=300s \
  job/ingress-nginx-admission-create -n ingress-nginx 2>/dev/null; then
    echo -e "${YELLOW}Warning: ingress-nginx-admission-create job did not complete${NC}"
    kubectl describe job ingress-nginx-admission-create -n ingress-nginx || true
fi

if ! kubectl wait --for=condition=complete --timeout=60s \
  job/ingress-nginx-admission-patch -n ingress-nginx 2>/dev/null; then
    echo -e "${YELLOW}Warning: ingress-nginx-admission-patch job did not complete${NC}"
    kubectl describe job ingress-nginx-admission-patch -n ingress-nginx || true
fi

echo "5.5.2. Waiting for internal admission jobs..."
if ! kubectl wait --for=condition=complete --timeout=300s \
  job/ingress-nginx-internal-admission-create -n ingress-nginx-internal 2>/dev/null; then
    echo -e "${YELLOW}Warning: ingress-nginx-internal-admission-create job did not complete${NC}"
    kubectl describe job ingress-nginx-internal-admission-create -n ingress-nginx-internal || true
fi

if ! kubectl wait --for=condition=complete --timeout=60s \
  job/ingress-nginx-internal-admission-patch -n ingress-nginx-internal 2>/dev/null; then
    echo -e "${YELLOW}Warning: ingress-nginx-internal-admission-patch job did not complete${NC}"
    kubectl describe job ingress-nginx-internal-admission-patch -n ingress-nginx-internal || true
fi

echo "5.5.3. Verifying admission secrets were created..."
if ! kubectl get secret ingress-nginx-external-admission -n ingress-nginx &>/dev/null; then
    echo -e "${RED}ERROR: Secret 'ingress-nginx-external-admission' was not created!${NC}"
    kubectl get secrets -n ingress-nginx
    fail_critical "Admission webhook secret not created for external ingress"
fi

if ! kubectl get secret ingress-nginx-internal-admission -n ingress-nginx-internal &>/dev/null; then
    echo -e "${RED}ERROR: Secret 'ingress-nginx-internal-admission' was not created!${NC}"
    kubectl get secrets -n ingress-nginx-internal
    fail_critical "Admission webhook secret not created for internal ingress"
fi

echo -e "${GREEN}✓ Admission secrets created successfully${NC}"

# Wait for deployments
echo "6. Waiting for deployments to be ready (timeout: 10 minutes)..."

# Check pods status first
echo "6.1. Checking external ingress pods..."
kubectl get pods -n ingress-nginx

echo "6.2. Checking internal ingress pods..."
kubectl get pods -n ingress-nginx-internal

# Wait for deployments with increased timeout
echo "6.3. Waiting for external ingress deployment..."
if ! kubectl wait --for=condition=available --timeout=600s \
  deployment/ingress-nginx-controller -n ingress-nginx; then
    echo -e "${YELLOW}⚠️  External ingress deployment timed out after 10 minutes.${NC}"
    echo "Checking deployment status..."
    kubectl get pods -n ingress-nginx
    kubectl describe deployment ingress-nginx-controller -n ingress-nginx | tail -30
    warn_timeout "External NGINX Ingress deployment timeout (non-critical)"
fi

echo "6.4. Waiting for internal ingress deployment..."
if ! kubectl wait --for=condition=available --timeout=600s \
  deployment/ingress-nginx-internal-controller -n ingress-nginx-internal; then
    echo -e "${YELLOW}⚠️  Internal ingress deployment timed out after 10 minutes.${NC}"
    echo "Checking deployment status..."
    kubectl get pods -n ingress-nginx-internal
    kubectl describe deployment ingress-nginx-internal-controller -n ingress-nginx-internal | tail -30
    warn_timeout "Internal NGINX Ingress deployment timeout (non-critical)"
fi

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
