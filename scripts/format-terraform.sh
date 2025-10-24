#!/bin/bash

# ==============================================================================
# FORMAT TERRAFORM FILES
# ==============================================================================

set -e

echo "Formatting all Terraform files..."
echo ""

# Format each phase
for phase in "00-iam" "01-networking" "02-kubernetes"; do
    echo "Formatting terraform/$phase..."
    terraform fmt -recursive "terraform/$phase/"
done

echo ""
echo "✅ All Terraform files formatted!"
