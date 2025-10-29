#!/bin/bash

# ==============================================================================
# Cleanup Kubernetes Jobs
# ==============================================================================

set -e

REGION="${AWS_DEFAULT_REGION:-sa-east-1}"
CLUSTERS=("eks-dev" "eks-stg" "eks-prd" "eks-sdx")

echo "=================================================="
echo "Cleanup Kubernetes Jobs"
echo "=================================================="
echo ""

for cluster in "${CLUSTERS[@]}"; do
    echo "Processing cluster: $cluster"
    
    # Update kubeconfig
    if aws eks update-kubeconfig \
        --name "$cluster" \
        --region "$REGION" &>/dev/null; then
        
        echo "  ✓ Connected to $cluster"
        
        # Delete problematic jobs if they exist
        kubectl delete job ingress-nginx-admission-create -n ingress-nginx --ignore-not-found=true 2>/dev/null
        kubectl delete job ingress-nginx-admission-patch -n ingress-nginx --ignore-not-found=true 2>/dev/null
        kubectl delete job ingress-nginx-internal-admission-create -n ingress-nginx-internal --ignore-not-found=true 2>/dev/null
        kubectl delete job ingress-nginx-internal-admission-patch -n ingress-nginx-internal --ignore-not-found=true 2>/dev/null
        
        echo "  ✓ Cleaned up jobs in $cluster"
    else
        echo "  ⚠ Cluster $cluster not accessible (may not exist yet)"
    fi
    
    echo ""
done

echo "=================================================="
echo "Cleanup completed!"
echo "=================================================="
echo ""
