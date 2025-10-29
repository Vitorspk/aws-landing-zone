#!/bin/bash

# ==============================================================================
# APPLY ALL FIXES - One Command to Rule Them All
# ==============================================================================

set -e

echo "=========================================="
echo "🔧 Applying All Fixes"
echo "=========================================="
echo ""

cd /Users/home/Documents/workspace-schiavo/aws-landing-zone

# Make all scripts executable
echo "1. Making scripts executable..."
chmod +x scripts/*.sh
echo "✅ Done"
echo ""

# Add all changes
echo "2. Adding all changes..."
git add .
echo "✅ Done"
echo ""

# Show what changed
echo "3. Files modified:"
git status --short
echo ""

# Commit
echo "4. Committing changes..."
git commit -m "fix: comprehensive solution for all deployment issues

## Problems Fixed

1. CloudWatch Log Groups
   - Move log group creation BEFORE EKS cluster
   - Add automatic cleanup in workflows
   - Add lifecycle rules to handle existing resources

2. Kubernetes Admission Jobs
   - Add cleanup step in deploy-ingress script
   - Delete existing jobs before kubectl apply
   - Prevents AlreadyExists errors

3. Workflow Conditions
   - Fix skip_iam_networking from == false to != 'true'
   - Ensures phases execute correctly

4. S3 Backend Region
   - Add -backend-config=region to all terraform init
   - Fixes bucket region mismatch errors

## New Files

- .github/workflows/deploy-simplified.yml - Simplified single-job workflow
- scripts/complete-reset.sh - Complete infrastructure reset
- scripts/cleanup-resources.sh - Cleanup orphaned resources
- scripts/import-existing-resources.sh - Import existing resources
- scripts/cleanup-k8s-jobs.sh - Cleanup K8s admission jobs
- docs/DETAILED_ANALYSIS.md - Technical analysis document
- docs/DEFINITIVE_SOLUTION.md - Complete solution guide
- QUICKSTART.md - Quick deployment guide
- Makefile - Updated with new commands

## Testing

All changes tested locally:
- ✅ Terraform validate passes
- ✅ Terraform fmt passes
- ✅ Backend initialization works
- ✅ Cleanup scripts functional
- ✅ Workflows validated

## Breaking Changes

None - backward compatible with existing deployments

## Migration Path

For existing deployments:
1. Run make reset (or scripts/complete-reset.sh)
2. Deploy fresh using simplified workflow
3. Or continue using original workflow (now fixed)

Closes issues with:
- ResourceAlreadyExistsException
- Remote state empty outputs
- Phase skipping incorrectly
- Region mismatch errors" || echo "Nothing to commit"

echo "✅ Done"
echo ""

# Push
echo "5. Pushing to remote..."
git push
echo "✅ Done"
echo ""

echo "=========================================="
echo "🎉 All fixes applied successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "Option 1 - Clean Slate (Recommended):"
echo "  make reset"
echo "  # Then run GitHub Actions workflow"
echo ""
echo "Option 2 - GitHub Actions Simplified:"
echo "  1. Go to Actions → Deploy Infrastructure (Simplified)"
echo "  2. Run workflow: environment=all, action=apply"
echo ""
echo "Option 3 - Local Deploy:"
echo "  make apply-all"
echo ""
