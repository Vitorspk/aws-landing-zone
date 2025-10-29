#!/bin/bash

# ==============================================================================
# Cleanup Conflicting AWS Resources
# ==============================================================================
# This script removes resources that might conflict with Terraform deployments
# ==============================================================================

set -e

REGION="${AWS_DEFAULT_REGION:-sa-east-1}"

echo "=================================================="
echo "AWS Resources Cleanup Script"
echo "=================================================="
echo ""
echo "Region: $REGION"
echo ""

# ==============================================================================
# Function to delete CloudWatch Log Groups
# ==============================================================================
delete_log_groups() {
    local patterns=(
        "/aws/vpc/shared-vpc/flow-logs"
        "/aws/eks/eks-dev/cluster"
        "/aws/eks/eks-stg/cluster"
        "/aws/eks/eks-prd/cluster"
        "/aws/eks/eks-sdx/cluster"
    )
    
    echo "Checking for conflicting CloudWatch Log Groups..."
    echo ""
    
    for pattern in "${patterns[@]}"; do
        if aws logs describe-log-groups \
            --log-group-name-prefix "$pattern" \
            --region "$REGION" \
            --query "logGroups[?logGroupName=='$pattern'].logGroupName" \
            --output text 2>/dev/null | grep -q "$pattern"; then
            
            echo "  ✗ Found: $pattern"
            echo "    Deleting..."
            
            aws logs delete-log-group \
                --log-group-name "$pattern" \
                --region "$REGION" 2>/dev/null || true
            
            echo "    ✓ Deleted"
        else
            echo "  ✓ Not found: $pattern (OK)"
        fi
    done
    
    echo ""
}

# ==============================================================================
# Function to check for stuck Terraform locks
# ==============================================================================
check_terraform_locks() {
    echo "Checking for stuck Terraform state locks..."
    echo ""
    
    local table_name="terraform-state-lock"
    
    if aws dynamodb describe-table \
        --table-name "$table_name" \
        --region "$REGION" &>/dev/null; then
        
        local lock_count=$(aws dynamodb scan \
            --table-name "$table_name" \
            --region "$REGION" \
            --select "COUNT" \
            --output text \
            --query "Count" 2>/dev/null || echo "0")
        
        if [ "$lock_count" -gt 0 ]; then
            echo "  ⚠ Warning: Found $lock_count active lock(s)"
            echo "  If deployments are failing, you may need to manually force-unlock"
            echo ""
            
            # List lock IDs
            aws dynamodb scan \
                --table-name "$table_name" \
                --region "$REGION" \
                --output text \
                --query "Items[*].LockID.S" 2>/dev/null | while read -r lock_id; do
                echo "    Lock ID: $lock_id"
            done
        else
            echo "  ✓ No active locks found"
        fi
    else
        echo "  ✓ Lock table doesn't exist yet (will be created)"
    fi
    
    echo ""
}

# ==============================================================================
# Main execution
# ==============================================================================

delete_log_groups
check_terraform_locks

echo "=================================================="
echo "Cleanup completed!"
echo "=================================================="
echo ""
echo "You can now run the deployment workflow."
echo ""
