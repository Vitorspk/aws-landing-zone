# Task 1.3: Fix `deploy_clusters` type mismatch in the example tfvars

**Date:** 2026-08-11  
**Branch:** `fix/terraform-correctness`  
**Commit:** `c6588c7`

## Summary

Fixed the `deploy_clusters` variable in `terraform/02-kubernetes/terraform.tfvars.example` to match its actual type definition (string) in `variables.tf`. The example previously documented it as a map, which would fail `terraform plan` with a type-mismatch error if copied verbatim.

## Changes Made

### File: `terraform/02-kubernetes/terraform.tfvars.example` (lines 7-23)

**Before:**
```hcl
# ==============================================================================
# CLUSTER SELECTION
# ==============================================================================
# Control which clusters to deploy
# Set to false to skip cluster creation

deploy_clusters = {
  dev = true   # Deploy dev cluster
  stg = true   # Deploy stg cluster
  prd = true   # Deploy prd cluster
  sdx = true   # Deploy sdx cluster
}

# Examples:
# - Deploy only dev: deploy_clusters = { dev = true, stg = false, prd = false, sdx = false }
# - Deploy dev + stg: deploy_clusters = { dev = true, stg = true, prd = false, sdx = false }
# - Deploy all: deploy_clusters = { dev = true, stg = true, prd = true, sdx = true }
```

**After:**
```hcl
# ==============================================================================
# CLUSTER SELECTION
# ==============================================================================
# Comma-separated list of clusters to deploy, or "all" for every cluster.

deploy_clusters = "all"

# Examples:
# - Deploy only dev: deploy_clusters = "dev"
# - Deploy dev + stg: deploy_clusters = "dev,stg"
# - Deploy all: deploy_clusters = "all"
```

**Change Stats:**
```
terraform/02-kubernetes/terraform.tfvars.example | 16 +++++-----------
1 file changed, 5 insertions(+), 11 deletions(-)
```

## Verification

**Note on approach:** `terraform validate` does not check variable values against tfvars files; it only validates static configuration structure regardless of variables. The `-backend=false init` approach also cannot be tested with `terraform plan` in this environment (no real AWS credentials), as the S3 backend would block the plan before reaching variable type-checking. Instead, we use a local backend to allow `terraform plan` to execute past initialization and reach the variable parsing phase.

Procedure: Replace the S3 backend with a local backend temporarily, initialize, and run `terraform plan` with the example tfvars:

```bash
$ mkdir -p /tmp/tfcheck && cp -r terraform/02-kubernetes /tmp/tfcheck/
$ cd /tmp/tfcheck/02-kubernetes
$ # Replace S3 backend with local backend
$ sed -i '' 's/backend "s3" {/backend "local" { path = "\/tmp\/tfcheck\/terraform.tfstate"/' backend.tf
$ # Remove invalid S3-specific args: bucket, key, encrypt, dynamodb_table (lines now empty)
$ rm -rf .terraform
$ terraform init
Terraform has been successfully initialized!
$ terraform plan -var-file=terraform.tfvars.example 2>&1 | head -40
[output shows data.terraform_remote_state.networking: Reading...]
[output shows data.terraform_remote_state.iam: Reading...]
[no output containing "deploy_clusters" or type error; first error is AWS credential-related]
$ rm -rf /tmp/tfcheck
```

**Result:** ✓ PASSED - Variable type checking succeeded. The plan progressed past variable parsing (no `deploy_clusters` type errors occurred). The later AWS credential errors are expected and unrelated to variable type correctness.

## Git Commit

```
[fix/terraform-correctness c6588c7] fix: correct deploy_clusters type in example tfvars (was a map, variable is a string)
 1 file changed, 5 insertions(+), 11 deletions(-)
```

**Commit Hash:** `c6588c7`

## Notes

- The example now accurately reflects the actual variable type (string), making it safe to copy verbatim
- The updated examples show the correct syntax: `"all"`, `"dev"`, or comma-separated values like `"dev,stg"`
- All documentation comments have been updated to reflect the correct usage
