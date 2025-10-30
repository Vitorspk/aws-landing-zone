#!/bin/bash

# ==============================================================================
# FORCE DELETE ALL AWS RESOURCES
# ==============================================================================
# This script forcefully deletes ALL resources, bypassing Terraform
# ==============================================================================

set -e

REGION="${AWS_DEFAULT_REGION:-sa-east-1}"
VPC_NAME="shared-vpc"

echo "=========================================="
echo "⚠️  FORCE DELETE ALL RESOURCES"
echo "=========================================="
echo ""
echo "This will MANUALLY delete all AWS resources:"
echo "  • All EKS Clusters"
echo "  • All Load Balancers" 
echo "  • All Network Interfaces"
echo "  • All NAT Gateways"
echo "  • All Subnets"
echo "  • All Route Tables"
echo "  • Internet Gateway"
echo "  • VPC"
echo "  • Security Groups"
echo "  • CloudWatch Log Groups"
echo ""
read -p "Type 'DELETE EVERYTHING' to proceed: " CONFIRM

if [ "$CONFIRM" != "DELETE EVERYTHING" ]; then
    echo "❌ Cancelled."
    exit 0
fi

echo ""
echo "🚨 Starting forced deletion..."
echo ""

# ==============================================================================
# 1. Delete All EKS Clusters
# ==============================================================================
echo "1. Deleting EKS Clusters..."

CLUSTERS=$(aws eks list-clusters --region "$REGION" --query 'clusters' --output text)

for CLUSTER in $CLUSTERS; do
    if [[ $CLUSTER == eks-* ]]; then
        echo "  Deleting cluster: $CLUSTER"
        
        # Delete node groups first
        NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER" --region "$REGION" --query 'nodegroups' --output text 2>/dev/null || echo "")
        
        for NG in $NODE_GROUPS; do
            echo "    Deleting node group: $NG"
            aws eks delete-nodegroup \
                --cluster-name "$CLUSTER" \
                --nodegroup-name "$NG" \
                --region "$REGION" || true
        done
        
        # Wait for node groups
        echo "    Waiting for node groups to delete..."
        sleep 30
        
        # Delete cluster
        echo "    Deleting cluster..."
        aws eks delete-cluster --name "$CLUSTER" --region "$REGION" || true
        echo "    ✓ Cluster deletion initiated"
    fi
done

echo "  Waiting 60s for clusters to start deleting..."
sleep 60
echo ""

# ==============================================================================
# 2. Get VPC ID
# ==============================================================================
echo "2. Finding VPC..."

VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=$VPC_NAME" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region "$REGION" 2>/dev/null)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "  ✓ VPC not found. May already be deleted."
    exit 0
fi

echo "  Found VPC: $VPC_ID"
echo ""

# ==============================================================================
# 3. Delete All Load Balancers
# ==============================================================================
echo "3. Deleting Load Balancers..."

# Application Load Balancers
ALB_ARNS=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$ALB_ARNS" ]; then
    for ARN in $ALB_ARNS; do
        echo "  Deleting ALB: $ARN"
        aws elbv2 delete-load-balancer --load-balancer-arn "$ARN" --region "$REGION" || true
    done
fi

# Classic Load Balancers
CLB_NAMES=$(aws elb describe-load-balancers \
    --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$CLB_NAMES" ]; then
    for NAME in $CLB_NAMES; do
        echo "  Deleting CLB: $NAME"
        aws elb delete-load-balancer --load-balancer-name "$NAME" --region "$REGION" || true
    done
fi

echo "  Waiting 90s for load balancers to be deleted..."
sleep 90
echo ""

# ==============================================================================
# 4. Delete All Network Interfaces
# ==============================================================================
echo "4. Deleting Network Interfaces..."

# Get all ENIs in the VPC
ENI_IDS=$(aws ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "NetworkInterfaces[].NetworkInterfaceId" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$ENI_IDS" ]; then
    for ENI in $ENI_IDS; do
        # Check if ENI is attached
        ATTACHMENT=$(aws ec2 describe-network-interfaces \
            --network-interface-ids "$ENI" \
            --query "NetworkInterfaces[0].Attachment.AttachmentId" \
            --output text \
            --region "$REGION" 2>/dev/null || echo "")
        
        if [ ! -z "$ATTACHMENT" ] && [ "$ATTACHMENT" != "None" ]; then
            echo "  Detaching ENI: $ENI"
            aws ec2 detach-network-interface \
                --attachment-id "$ATTACHMENT" \
                --region "$REGION" \
                --force || true
            sleep 5
        fi
        
        echo "  Deleting ENI: $ENI"
        aws ec2 delete-network-interface \
            --network-interface-id "$ENI" \
            --region "$REGION" || true
    done
    
    echo "  Waiting 30s for ENIs to be deleted..."
    sleep 30
else
    echo "  ✓ No ENIs found"
fi

echo ""

# ==============================================================================
# 5. Delete NAT Gateways
# ==============================================================================
echo "5. Deleting NAT Gateways..."

NAT_IDS=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    --query "NatGateways[].NatGatewayId" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$NAT_IDS" ]; then
    for NAT in $NAT_IDS; do
        echo "  Deleting NAT Gateway: $NAT"
        aws ec2 delete-nat-gateway --nat-gateway-id "$NAT" --region "$REGION" || true
    done
    
    echo "  Waiting 60s for NAT gateways to delete..."
    sleep 60
else
    echo "  ✓ No NAT Gateways found"
fi

echo ""

# ==============================================================================
# 6. Release Elastic IPs
# ==============================================================================
echo "6. Releasing Elastic IPs..."

EIP_IDS=$(aws ec2 describe-addresses \
    --filters "Name=domain,Values=vpc" \
    --query "Addresses[?AssociationId==null].AllocationId" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$EIP_IDS" ]; then
    for EIP in $EIP_IDS; do
        echo "  Releasing EIP: $EIP"
        aws ec2 release-address --allocation-id "$EIP" --region "$REGION" || true
    done
else
    echo "  ✓ No unassociated EIPs found"
fi

echo ""

# ==============================================================================
# 7. Delete VPC Endpoints
# ==============================================================================
echo "7. Deleting VPC Endpoints..."

ENDPOINT_IDS=$(aws ec2 describe-vpc-endpoints \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "VpcEndpoints[].VpcEndpointId" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$ENDPOINT_IDS" ]; then
    for ENDPOINT in $ENDPOINT_IDS; do
        echo "  Deleting VPC Endpoint: $ENDPOINT"
        aws ec2 delete-vpc-endpoints --vpc-endpoint-ids "$ENDPOINT" --region "$REGION" || true
    done
    
    echo "  Waiting 30s for endpoints to delete..."
    sleep 30
else
    echo "  ✓ No VPC Endpoints found"
fi

echo ""

# ==============================================================================
# 8. Now run Terraform destroy (should work now)
# ==============================================================================
echo "8. Running Terraform destroy..."
echo ""

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$REPO_ROOT"

echo "  8.1. Destroying Phase 2 - Kubernetes..."
cd terraform/02-kubernetes
terraform init -backend-config="region=$REGION" || true
terraform destroy -var="region=$REGION" -var="deploy_clusters=all" -auto-approve || echo "    ⚠ Continuing..."
cd ../..
echo ""

echo "  8.2. Destroying Phase 1 - Networking..."
cd terraform/01-networking
terraform init -backend-config="region=$REGION" || true
terraform destroy -var="region=$REGION" -auto-approve || echo "    ⚠ Continuing..."
cd ../..
echo ""

echo "  8.3. Destroying Phase 0 - IAM..."
cd terraform/00-iam
terraform init -backend-config="region=$REGION" || true
terraform destroy -var="region=$REGION" -auto-approve || echo "    ⚠ Continuing..."
cd ../..
echo ""

# ==============================================================================
# 9. Final Cleanup - Delete remaining resources manually
# ==============================================================================
echo "9. Final cleanup of remaining resources..."

# Delete any remaining subnets
SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[].SubnetId" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$SUBNET_IDS" ]; then
    for SUBNET in $SUBNET_IDS; do
        echo "  Force deleting subnet: $SUBNET"
        aws ec2 delete-subnet --subnet-id "$SUBNET" --region "$REGION" || true
    done
fi

# Delete Internet Gateway
IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query "InternetGateways[0].InternetGatewayId" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
    echo "  Detaching Internet Gateway: $IGW_ID"
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$REGION" || true
    echo "  Deleting Internet Gateway: $IGW_ID"
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$REGION" || true
fi

# Delete Route Tables
RT_IDS=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$RT_IDS" ]; then
    for RT in $RT_IDS; do
        echo "  Deleting route table: $RT"
        aws ec2 delete-route-table --route-table-id "$RT" --region "$REGION" || true
    done
fi

# Delete Security Groups
SG_IDS=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[?GroupName!='default'].GroupId" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$SG_IDS" ]; then
    for SG in $SG_IDS; do
        echo "  Deleting security group: $SG"
        aws ec2 delete-security-group --group-id "$SG" --region "$REGION" || true
    done
fi

# Delete VPC
echo "  Deleting VPC: $VPC_ID"
aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION" || true

echo ""

# ==============================================================================
# 10. Delete CloudWatch Log Groups
# ==============================================================================
echo "10. Deleting CloudWatch Log Groups..."

LOG_GROUPS=(
    "/aws/vpc/shared-vpc/flow-logs"
    "/aws/eks/eks-dev/cluster"
    "/aws/eks/eks-stg/cluster"
    "/aws/eks/eks-prd/cluster"
    "/aws/eks/eks-sdx/cluster"
)

for LOG_GROUP in "${LOG_GROUPS[@]}"; do
    aws logs delete-log-group --log-group-name "$LOG_GROUP" --region "$REGION" 2>/dev/null || true
done

echo "  ✓ Log groups deleted"
echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "=========================================="
echo "✅ Forced deletion completed!"
echo "=========================================="
echo ""
echo "All resources have been forcefully removed."
echo ""