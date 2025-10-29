#!/bin/bash

# ==============================================================================
# Delete Existing CloudWatch Log Group
# ==============================================================================

set -e

REGION="sa-east-1"
LOG_GROUP_NAME="/aws/vpc/shared-vpc/flow-logs"

echo "=================================================="
echo "Deleting CloudWatch Log Group"
echo "=================================================="
echo ""
echo "Region: $REGION"
echo "Log Group: $LOG_GROUP_NAME"
echo ""

# Check if log group exists
if aws logs describe-log-groups \
    --log-group-name-prefix "$LOG_GROUP_NAME" \
    --region "$REGION" \
    --query "logGroups[?logGroupName=='$LOG_GROUP_NAME']" \
    --output text | grep -q "$LOG_GROUP_NAME"; then
    
    echo "Log group exists. Deleting..."
    
    aws logs delete-log-group \
        --log-group-name "$LOG_GROUP_NAME" \
        --region "$REGION"
    
    echo "✓ Log group deleted successfully!"
else
    echo "✓ Log group does not exist. Nothing to delete."
fi

echo ""
echo "You can now run the deployment again."
echo ""
