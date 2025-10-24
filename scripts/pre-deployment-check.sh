#!/bin/bash

# ==============================================================================
# PRE-DEPLOYMENT CHECK SCRIPT
# ==============================================================================

set -e

echo "========================================="
echo "AWS Landing Zone - Pre-Deployment Check"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Check if running in correct directory
if [ ! -f "README.md" ]; then
    echo -e "${RED}Error: Please run this script from the repository root${NC}"
    exit 1
fi

echo "1. Checking prerequisites..."
echo "----------------------------"

# Check AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
    print_status 0 "AWS CLI installed: $AWS_VERSION"
else
    print_status 1 "AWS CLI not found"
    exit 1
fi

# Check Terraform
if command -v terraform &> /dev/null; then
    TF_VERSION=$(terraform version -json | jq -r '.terraform_version')
    print_status 0 "Terraform installed: v$TF_VERSION"
else
    print_status 1 "Terraform not found"
    exit 1
fi

# Check kubectl
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion')
    print_status 0 "kubectl installed: $KUBECTL_VERSION"
else
    print_status 1 "kubectl not found (optional but recommended)"
fi

echo ""
echo "2. Checking AWS credentials..."
echo "-------------------------------"

# Check AWS credentials
if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    print_status 0 "AWS credentials configured"
    echo "   Account: $AWS_ACCOUNT"
    echo "   User: $AWS_USER"
else
    print_status 1 "AWS credentials not configured or invalid"
    exit 1
fi

echo ""
echo "3. Checking S3 backend..."
echo "-------------------------"

# Check if S3 bucket exists
BUCKET_NAME="vschiavo-home-terraform-state"
if aws s3 ls "s3://$BUCKET_NAME" &> /dev/null; then
    print_status 0 "S3 bucket exists: $BUCKET_NAME"
else
    print_status 1 "S3 bucket not found: $BUCKET_NAME"
    echo ""
    echo "   To create the bucket, run:"
    echo "   aws s3 mb s3://$BUCKET_NAME --region sa-east-1"
    echo "   aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled"
    echo "   aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration '{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}'"
    exit 1
fi

# Check if DynamoDB table exists
TABLE_NAME="terraform-state-lock"
if aws dynamodb describe-table --table-name $TABLE_NAME &> /dev/null; then
    print_status 0 "DynamoDB table exists: $TABLE_NAME"
else
    print_status 1 "DynamoDB table not found: $TABLE_NAME"
    echo ""
    echo "   To create the table, run:"
    echo "   aws dynamodb create-table \\"
    echo "     --table-name $TABLE_NAME \\"
    echo "     --attribute-definitions AttributeName=LockID,AttributeType=S \\"
    echo "     --key-schema AttributeName=LockID,KeyType=HASH \\"
    echo "     --billing-mode PAY_PER_REQUEST \\"
    echo "     --region sa-east-1"
    exit 1
fi

echo ""
echo "4. Validating Terraform configuration..."
echo "-----------------------------------------"

# Validate each phase
for phase in "00-iam" "01-networking" "02-kubernetes"; do
    echo "   Validating terraform/$phase..."
    cd "terraform/$phase"
    
    if terraform fmt -check -recursive > /dev/null 2>&1; then
        print_status 0 "$phase: Formatting OK"
    else
        print_status 1 "$phase: Formatting needs attention (run: terraform fmt -recursive)"
    fi
    
    if terraform init -backend=false > /dev/null 2>&1; then
        if terraform validate > /dev/null 2>&1; then
            print_status 0 "$phase: Validation passed"
        else
            print_status 1 "$phase: Validation failed"
            terraform validate
            exit 1
        fi
    else
        print_status 1 "$phase: Init failed"
        exit 1
    fi
    
    cd - > /dev/null
done

echo ""
echo "========================================="
echo -e "${GREEN}All checks passed!${NC}"
echo "========================================="
echo ""
echo "You can now proceed with deployment:"
echo "  make init-iam && make apply-iam"
echo "  make init-networking && make apply-networking"
echo "  make init-kubernetes && make apply-kubernetes"
echo ""
