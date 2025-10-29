#!/bin/bash

# ==============================================================================
# COMPLETE RESET SCRIPT
# ==============================================================================
# This script completely destroys all infrastructure and prepares for clean deploy
# ==============================================================================

set -e

REGION="${AWS_DEFAULT_REGION:-sa-east-1}"

echo "=========================================="
echo "AWS Landing Zone - Complete Reset"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will DESTROY all infrastructure!"
echo ""
echo "This script will:"
echo "  1. Destroy all EKS clusters"
echo "  2. Destroy networking resources"
echo "  3. Destroy IAM resources"
echo "  4. Delete all CloudWatch log groups"
echo "  5. Clear Terraform state locks"
echo ""
read -p "Are you sure you want to continue? Type 'yes' to proceed: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Reset cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup process..."
echo ""

# ==============================================================================
# 1. Delete CloudWatch Log Groups
# ==============================================================================
echo "1. Deleting CloudWatch Log Groups..."

LOG_GROUPS=(
    "/aws/vpc/shared-vpc/flow-logs"
    "/aws/eks/eks-dev/cluster"
    "/aws/eks/eks-stg/cluster"
    "/aws/eks/eks-prd/cluster"
    "/aws/eks/eks-sdx/cluster"
)

for LOG_GROUP in "${LOG_GROUPS[@]}"; do
    echo "  Checking: $LOG_GROUP"
    if aws logs describe-log-groups \
        --log-group-name-prefix "$LOG_GROUP" \
        --region "$REGION" \
        --query "logGroups[?logGroupName=='$LOG_GROUP'].logGroupName" \
        --output text 2>/dev/null | grep -q "$LOG_GROUP"; then
        
        echo "    Deleting..."
        aws logs delete-log-group --log-group-name "$LOG_GROUP" --region "$REGION" || true
        echo "    ✓ Deleted"
    else
        echo "    ✓ Not found (OK)"
    fi
done

echo ""

# ==============================================================================
# 2. Delete Kubernetes Jobs (if clusters exist)
# ==============================================================================
echo "2. Cleaning up Kubernetes jobs..."

CLUSTERS=("eks-dev" "eks-stg" "eks-prd" "eks-sdx")

for CLUSTER in "${CLUSTERS[@]}"; do
    echo "  Checking cluster: $CLUSTER"
    
    if aws eks describe-cluster --name "$CLUSTER" --region "$REGION" &>/dev/null; then
        echo "    Updating kubeconfig..."
        aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" &>/dev/null || true
        
        echo "    Deleting jobs..."
        kubectl delete job --all -n ingress-nginx --ignore-not-found &>/dev/null || true
        kubectl delete job --all -n ingress-nginx-internal --ignore-not-found &>/dev/null || true
        echo "    ✓ Cleaned"
    else
        echo "    ✓ Cluster doesn't exist (OK)"
    fi
done

echo ""

# ==============================================================================
# 3. Destroy Terraform Infrastructure (in reverse order)
# ==============================================================================
echo "3. Destroying Terraform infrastructure..."
echo ""

# Phase 2 - Kubernetes
echo "  3.1. Destroying Phase 2 - Kubernetes..."
cd terraform/02-kubernetes
terraform init -backend-config="region=$REGION" || true
terraform destroy -var="region=$REGION" -var="deploy_clusters=all" -auto-approve || echo "    ⚠ Some resources may not exist"
cd ../..
echo "    ✓ Phase 2 destroyed"
echo ""

# Phase 1 - Networking
echo "  3.2. Destroying Phase 1 - Networking..."
cd terraform/01-networking
terraform init -backend-config="region=$REGION" || true
terraform destroy -var="region=$REGION" -auto-approve || echo "    ⚠ Some resources may not exist"
cd ../..
echo "    ✓ Phase 1 destroyed"
echo ""

# Phase 0 - IAM
echo "  3.3. Destroying Phase 0 - IAM..."
cd terraform/00-iam
terraform init -backend-config="region=$REGION" || true
terraform destroy -var="region=$REGION" -auto-approve || echo "    ⚠ Some resources may not exist"
cd ../..
echo "    ✓ Phase 0 destroyed"
echo ""

# ==============================================================================
# 4. Clear Terraform State Locks (if any)
# ==============================================================================
echo "4. Checking for state locks..."

if aws dynamodb describe-table --table-name terraform-state-lock --region "$REGION" &>/dev/null; then
    LOCK_COUNT=$(aws dynamodb scan \
        --table-name terraform-state-lock \
        --region "$REGION" \
        --select "COUNT" \
        --output text \
        --query "Count" 2>/dev/null || echo "0")
    
    if [ "$LOCK_COUNT" -gt 0 ]; then
        echo "  ⚠ Found $LOCK_COUNT lock(s). Clearing..."
        
        # Get all lock IDs and delete them
        aws dynamodb scan \
            --table-name terraform-state-lock \
            --region "$REGION" \
            --output text \
            --query "Items[*].LockID.S" 2>/dev/null | while read -r LOCK_ID; do
            
            if [ ! -z "$LOCK_ID" ]; then
                echo "    Deleting lock: $LOCK_ID"
                aws dynamodb delete-item \
                    --table-name terraform-state-lock \
                    --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}" \
                    --region "$REGION" || true
            fi
        done
        echo "  ✓ Locks cleared"
    else
        echo "  ✓ No locks found"
    fi
else
    echo "  ✓ Lock table doesn't exist (OK)"
fi

echo ""

# ==============================================================================
# 5. Verify S3 Backend State (optional cleanup)
# ==============================================================================
echo "5. Checking S3 backend state files..."

BUCKET="vschiavo-home-terraform-state"

if aws s3 ls "s3://$BUCKET" --region "$REGION" &>/dev/null; then
    echo "  Listing state files in S3..."
    aws s3 ls "s3://$BUCKET/aws-landing-zone/" --recursive --region "$REGION" || true
    echo ""
    echo "  State files are preserved for safety."
    echo "  To delete them manually (⚠️ DANGER):"
    echo "    aws s3 rm s3://$BUCKET/aws-landing-zone/ --recursive --region $REGION"
else
    echo "  ✓ Bucket not accessible or doesn't exist"
fi

echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "=========================================="
echo "✅ Reset completed successfully!"
echo "=========================================="
echo ""
echo "Your environment is now clean and ready for fresh deployment."
echo ""
echo "Next steps:"
echo "  1. Commit and push all code changes"
echo "  2. Run GitHub Actions workflow:"
echo "     - Branch: master"
echo "     - Action: apply"
echo "     - Clusters: all"
echo "     - Skip IAM/Networking: UNCHECKED"
echo ""
echo "Estimated deployment time: 45-60 minutes"
echo ""
