#!/bin/bash

# ==============================================================================
# Import Existing Resources into Terraform State
# ==============================================================================

set -e

REGION="${AWS_DEFAULT_REGION:-sa-east-1}"

echo "=================================================="
echo "Import Existing AWS Resources to Terraform"
echo "=================================================="
echo ""

cd terraform/02-kubernetes

# Initialize Terraform
echo "Initializing Terraform..."
terraform init -backend-config="region=$REGION"
echo ""

# Import log groups if they exist
echo "Importing CloudWatch Log Groups..."

CLUSTERS=("dev" "stg" "prd" "sdx")

for cluster in "${CLUSTERS[@]}"; do
    LOG_GROUP="/aws/eks/eks-$cluster/cluster"
    
    # Check if log group exists
    if aws logs describe-log-groups \
        --log-group-name-prefix "$LOG_GROUP" \
        --region "$REGION" \
        --query "logGroups[?logGroupName=='$LOG_GROUP'].logGroupName" \
        --output text 2>/dev/null | grep -q "$LOG_GROUP"; then
        
        echo "  Found existing log group: $LOG_GROUP"
        echo "  Importing into Terraform state..."
        
        terraform import \
            -var="region=$REGION" \
            -var="deploy_clusters=all" \
            "module.eks_$cluster[0].aws_cloudwatch_log_group.cluster" \
            "$LOG_GROUP" 2>/dev/null || echo "  ⚠ Already imported or doesn't need import"
        
        echo "  ✓ Processed: $LOG_GROUP"
    else
        echo "  ✓ Log group doesn't exist: $LOG_GROUP (OK)"
    fi
done

echo ""
echo "=================================================="
echo "Import completed!"
echo "=================================================="
echo ""
echo "You can now run terraform apply again."
echo ""
