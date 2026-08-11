# Terraform Best-Practices Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `aws-landing-zone`'s Terraform code, CI, and docs in line with common best practices, fixing the concrete issues identified in the 2026-08-11 repository survey and design spec — mirroring the already-completed `azure-landing-zone` hardening pass, without adding new infrastructure capability.

**Architecture:** Seven independently-mergeable PRs, in order: (A) Terraform correctness, (B) EKS public endpoint, (C) destroy-infrastructure.yml safety, (D) CI/CD hardening, (E) Makefile, (F) docs freshness, (G) CLAUDE.md/settings.json. Each PR is its own branch → commits per task → `gh pr create` → CI green → squash-merge, matching the flow already used on `azure-landing-zone`.

**Tech Stack:** Terraform >= 1.5.0, `hashicorp/aws ~> 5.0`, GitHub Actions, `tflint` 0.64.0 (+ `tflint-ruleset-aws` — already present, version 0.27.0), `checkov` 3.3.0.

## Global Constraints

- No live AWS infrastructure exists right now — every task verifies via `terraform fmt`/`validate`/`plan` (using `-backend=false` where noted), never `apply`, unless a task explicitly says otherwise.
- Every new/changed variable keeps a `description`.
- Do not restrict the EKS `public_access_cidrs` default — it must stay `["0.0.0.0/0"]` so `deploy-ingress-nginx.yml`'s GitHub-hosted-runner `kubectl` access keeps working. This PR only makes the value **configurable**, not more restrictive.
- Do not write the 5 missing shell scripts (`check-prerequisites.sh`, `setup-backend.sh`, `cleanup-resources.sh`, `complete-reset.sh`, `cleanup-k8s-jobs.sh`) — simplify the Makefile instead.
- Do not rewrite `docs/PROJECT_SUMMARY.md` — delete it.
- Follow the existing git workflow: feature branch off `master`, commit per task, push, `gh pr create`, wait for checks, `gh pr merge --squash --delete-branch`.
- `tflint-ruleset-aws` is **already** configured in both `.tflint.hcl` files (version 0.27.0) — the design spec's PR D item "switch to the AWS tflint ruleset" was based on an incomplete reading of the survey and is dropped from this plan. Only the two files' rule-block inconsistency needs reconciling (see Task D.4).

---

## PR A — Terraform correctness

**Branch:** `fix/terraform-correctness`

### Task A.1: Add `default = "sa-east-1"` to `region` in all three root modules

**Files:**
- Modify: `terraform/00-iam/variables.tf:5-8`
- Modify: `terraform/01-networking/variables.tf:5-8`
- Modify: `terraform/02-kubernetes/variables.tf:5-8`

**Interfaces:** none — same variable name/type in all three, only adding a `default`.

- [ ] **Step 1: Add the default in `terraform/00-iam/variables.tf`**

Replace:
```hcl
variable "region" {
  description = "AWS Region"
  type        = string
}
```
with:
```hcl
variable "region" {
  description = "AWS Region"
  type        = string
  default     = "sa-east-1"
}
```

- [ ] **Step 2: Add the default in `terraform/01-networking/variables.tf`**

Replace:
```hcl
variable "region" {
  description = "AWS region"
  type        = string
}
```
with:
```hcl
variable "region" {
  description = "AWS region"
  type        = string
  default     = "sa-east-1"
}
```

- [ ] **Step 3: Add the default in `terraform/02-kubernetes/variables.tf`**

Replace:
```hcl
variable "region" {
  description = "AWS region"
  type        = string
}
```
with:
```hcl
variable "region" {
  description = "AWS region"
  type        = string
  default     = "sa-east-1"
}
```

- [ ] **Step 4: Verify each module still initializes and validates**

Run for each of the three directories (`terraform/00-iam`, `terraform/01-networking`, `terraform/02-kubernetes`):
```bash
cd terraform/<module> && terraform init -backend=false -upgrade=false && terraform validate
```
Expected: `Success! The configuration is valid.` in all three.

- [ ] **Step 5: Verify a plan with no `-var` no longer blocks on region**

Run: `cd terraform/00-iam && terraform plan -out=/dev/null 2>&1 | head -5`
Expected: no "var.region" interactive-prompt text; the plan proceeds to whatever the next real error is (likely an AWS auth/backend error, since there's no real backend access in this environment — that's fine, the point is it gets past variable collection instantly instead of hanging).

- [ ] **Step 6: Commit**

```bash
git add terraform/00-iam/variables.tf terraform/01-networking/variables.tf terraform/02-kubernetes/variables.tf
git commit -m "fix: default region to sa-east-1 across all root modules

Matches deploy-infrastructure.yml's own hardcoded AWS_REGION default.
Without this, a required variable with no default and no CI-supplied
value blocks Terraform on an interactive prompt that never resolves
on a non-interactive runner — the exact bug that caused a multi-hour
incident on the sibling azure-landing-zone repo."
```

### Task A.2: Add `validation` block to `deploy_clusters`

**Files:**
- Modify: `terraform/02-kubernetes/variables.tf` (the `deploy_clusters` variable, right after Task A.1's edit to this same file)

- [ ] **Step 1: Add the validation block**

Replace:
```hcl
variable "deploy_clusters" {
  description = "Comma-separated list of clusters to deploy (dev,stg,prd,sdx) or 'all' for all clusters"
  type        = string
  default     = "all"
}
```
with:
```hcl
variable "deploy_clusters" {
  description = "Comma-separated list of clusters to deploy (dev,stg,prd,sdx) or 'all' for all clusters"
  type        = string
  default     = "all"

  validation {
    condition = var.deploy_clusters == "all" || alltrue([
      for c in split(",", var.deploy_clusters) : contains(["dev", "stg", "prd", "sdx"], c)
    ])
    error_message = "deploy_clusters must be \"all\" or a comma-separated list containing only: dev, stg, prd, sdx."
  }
}
```

- [ ] **Step 2: Verify it rejects a bad value**

Run: `cd terraform/02-kubernetes && terraform init -backend=false && terraform plan -var="deploy_clusters=dev,stx" -out=/dev/null`
Expected: fails during variable validation with `deploy_clusters must be "all" or a comma-separated list containing only: dev, stg, prd, sdx.`

- [ ] **Step 3: Verify the real default still works**

Run: `terraform plan -var="deploy_clusters=all" -out=/dev/null`
Expected: passes validation (may fail later for unrelated reasons — no live backend in this environment — the point is it gets past the validation check).

- [ ] **Step 4: Commit**

```bash
git add terraform/02-kubernetes/variables.tf
git commit -m "fix: validate deploy_clusters against known environments"
```

### Task A.3: Fix `deploy_clusters` type mismatch in the example tfvars

**Files:**
- Modify: `terraform/02-kubernetes/terraform.tfvars.example:13-23`

**Interfaces:** none — `deploy_clusters` is a `string` per `variables.tf`; the example currently sets it as a map, which fails `terraform plan` with a type error if copied verbatim.

- [ ] **Step 1: Fix the example**

Replace:
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
with:
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

- [ ] **Step 2: Verify the example file actually works if copied**

```bash
cd terraform/02-kubernetes
cp terraform.tfvars.example /tmp/test.tfvars
terraform init -backend=false
terraform plan -var-file=/tmp/test.tfvars -out=/dev/null 2>&1 | head -10
rm /tmp/test.tfvars
```
Expected: no type-mismatch error on `deploy_clusters` (any remaining output should be unrelated, e.g. a missing-backend/auth error — there is no live backend in this environment).

- [ ] **Step 3: Commit**

```bash
git add terraform/02-kubernetes/terraform.tfvars.example
git commit -m "fix: correct deploy_clusters type in example tfvars (was a map, variable is a string)"
```

### Task A.4: Full-module validation sweep, open PR, merge

- [ ] **Step 1: Format and validate every module**

```bash
terraform fmt -check -recursive terraform/
```
Expected: no output (already formatted).

Run for each of `00-iam`, `01-networking`, `02-kubernetes`, `02-kubernetes/modules/eks-cluster`:
```bash
cd terraform/<module> && terraform init -backend=false -upgrade=false && terraform validate
```
Expected: `Success! The configuration is valid.` in all four.

- [ ] **Step 2: Push, open PR, wait for checks, merge**

```bash
git push -u origin fix/terraform-correctness
gh pr create --repo Vitorspk/aws-landing-zone \
  --title "fix: Terraform correctness pass" \
  --body "Adds a default region (matching deploy-infrastructure.yml's own AWS_REGION default) to all three root modules — without it, any ad-hoc plan/apply blocks forever on an interactive prompt on a non-interactive runner, the same bug that caused a multi-hour incident on azure-landing-zone. Adds a validation block to deploy_clusters, and fixes a type mismatch in 02-kubernetes/terraform.tfvars.example (deploy_clusters was documented as a map; the real variable is a string). Part of the post-azure-landing-zone hardening pass — see docs/superpowers/specs/2026-08-11-terraform-best-practices-hardening-design.md."
```
Wait for `Validate Terraform` (matrix) and `claude-review` to pass, then:
```bash
gh pr merge --repo Vitorspk/aws-landing-zone --squash --delete-branch <PR-number>
```

---

## PR B — EKS public endpoint

**Branch:** `fix/eks-public-endpoint-configurable`

### Task B.1: Add `public_access_cidrs` variable to the `eks-cluster` module

**Files:**
- Modify: `terraform/02-kubernetes/modules/eks-cluster/variables.tf` (add near the other network variables, after `cluster_security_group_id`)

- [ ] **Step 1: Add the variable**

Insert after the `cluster_security_group_id` variable block (before the `# NODE GROUP VARIABLES` section header):
```hcl

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the EKS public API endpoint. Defaults to open (0.0.0.0/0) because deploy-ingress-nginx.yml runs kubectl from GitHub-hosted runners outside the VPC — restricting this without a self-hosted runner or VPN would break that workflow."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
```

- [ ] **Step 2: Use it in the cluster resource**

In `terraform/02-kubernetes/modules/eks-cluster/main.tf`, replace:
```hcl
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [var.cluster_security_group_id]
  }
```
with:
```hcl
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [var.cluster_security_group_id]
  }
```

- [ ] **Step 3: Verify**

```bash
cd terraform/02-kubernetes/modules/eks-cluster && terraform init -backend=false && terraform validate
```
Expected: `Success! The configuration is valid.`

- [ ] **Step 4: Commit**

```bash
git add terraform/02-kubernetes/modules/eks-cluster/variables.tf terraform/02-kubernetes/modules/eks-cluster/main.tf
git commit -m "fix: make EKS public_access_cidrs configurable (was hardcoded to 0.0.0.0/0)"
```

### Task B.2: Add a documented checkov skip for the two now-intentional findings

**Files:**
- Modify: `terraform/02-kubernetes/modules/eks-cluster/main.tf` (the `aws_eks_cluster "main"` resource block)

**Note:** `checkov -d terraform/` reports `CKV_AWS_39` ("Ensure Amazon EKS public endpoint disabled") and `CKV_AWS_38` ("Ensure Amazon EKS public endpoint not accessible to 0.0.0.0/0") for this resource, once for each of the 4 calling instances (`module.eks_dev`/`eks_stg`/`eks_prd`/`eks_sdx`). Both findings are the direct, intentional consequence of the "keep the default open" decision (Global Constraints) — this is not deferred to PR D because it belongs with the code change that causes it.

- [ ] **Step 1: Add the skip comments**

Checkov only honors a skip comment as the **first line inside** the resource block, immediately after the opening `{` — verified experimentally (a comment above the `resource` line has no effect; the tool still reports the check as failed). In `terraform/02-kubernetes/modules/eks-cluster/main.tf`, change:
```hcl
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
```
to:
```hcl
resource "aws_eks_cluster" "main" {
  #checkov:skip=CKV_AWS_39:Public endpoint intentionally enabled - deploy-ingress-nginx.yml runs kubectl from GitHub-hosted runners outside the VPC. See docs/superpowers/specs/2026-08-11-terraform-best-practices-hardening-design.md.
  #checkov:skip=CKV_AWS_38:public_access_cidrs is intentionally 0.0.0.0/0 by default (now configurable via var.public_access_cidrs) for the same CI reason as above.
  name     = var.cluster_name
```

- [ ] **Step 2: Verify the skip takes effect for all 4 calling instances**

Run: `checkov -d terraform/ --compact --quiet --check CKV_AWS_39,CKV_AWS_38`
Expected: `Passed checks: 0, Failed checks: 0, Skipped checks: 8` (2 checks × 4 clusters — verified experimentally while writing this plan; a misplaced comment would show `Failed checks: 8` instead).

- [ ] **Step 3: Commit**

```bash
git add terraform/02-kubernetes/modules/eks-cluster/main.tf
git commit -m "docs: add checkov skip for the intentionally-open EKS public endpoint"
```

### Task B.3: Open PR, wait for checks, merge

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin fix/eks-public-endpoint-configurable
gh pr create --repo Vitorspk/aws-landing-zone \
  --title "fix: make EKS public_access_cidrs configurable" \
  --body "The EKS API server's public_access_cidrs was hardcoded to 0.0.0.0/0 with no variable to restrict it, directly contradicting README.md/docs/SECURITY.md/docs/ARCHITECTURE.md's claims of a 'private cluster'. This PR makes it a variable (default unchanged, still 0.0.0.0/0, so CI keeps working — deploy-ingress-nginx.yml's kubectl runs from GitHub-hosted runners outside the VPC and would break if this were restricted without a bigger architecture change). Doc corrections land in a later PR once every code change in this pass is known. Adds a documented checkov skip for the two findings (CKV_AWS_39, CKV_AWS_38) this default triggers. Part of the post-azure-landing-zone hardening pass."
```

- [ ] **Step 2: Wait for checks, then squash-merge**

```bash
gh pr merge --repo Vitorspk/aws-landing-zone --squash --delete-branch <PR-number>
```

---

## PR C — `destroy-infrastructure.yml` safety

**Branch:** `fix/destroy-infrastructure-safety`

### Task C.1: Add a typed confirmation gate

**Files:**
- Modify: `.github/workflows/destroy-infrastructure.yml` (the `on.workflow_dispatch.inputs` block and the first step)

- [ ] **Step 1: Add the `confirm_destroy` input**

Replace:
```yaml
on:
  workflow_dispatch:
    inputs:
      scope:
        description: 'What to destroy'
        required: true
        type: choice
        options:
          - kubernetes-only
          - all
```
with:
```yaml
on:
  workflow_dispatch:
    inputs:
      scope:
        description: 'What to destroy'
        required: true
        type: choice
        options:
          - kubernetes-only
          - all
      confirm_destroy:
        description: 'Type "DESTROY" to confirm destruction'
        required: true
        type: string
```

- [ ] **Step 2: Add a validation step before any AWS calls**

Insert a new step right after `Checkout code` (before `Configure AWS credentials`):
```yaml
      - name: Validate confirmation
        run: |
          if [ "${{ github.event.inputs.confirm_destroy }}" != "DESTROY" ]; then
            echo "❌ Destruction not confirmed. You must type 'DESTROY' (all caps) to confirm."
            exit 1
          fi
          echo "✅ Destruction confirmed"
```

- [ ] **Step 3: Verify the workflow YAML is still valid**

Run: `actionlint .github/workflows/destroy-infrastructure.yml`
Expected: no new findings (compare against `git stash`'d output of the same command on the pre-edit file — any findings should be identical, pre-existing shellcheck style nits in the unrelated cleanup steps, not new ones from this edit).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/destroy-infrastructure.yml
git commit -m "fix: require typing DESTROY to confirm destroy-infrastructure.yml

Previously this workflow had a scope choice but zero confirmation
gate — it destroyed on dispatch with no typed confirmation at all,
unlike destroy-ingress-nginx.yml (which at least required 'yes').
Matches azure-landing-zone's deploy-infrastructure.yml pattern."
```

### Task C.2: Scope down the "Clear Terraform Locks" step

**Files:**
- Modify: `.github/workflows/destroy-infrastructure.yml` (the `Clear Terraform Locks` step, near the end)

**Note:** Terraform's S3 backend with a DynamoDB lock table stores each lock under `LockID = "<bucket>/<key>"`. The three state keys in this repo are `aws-landing-zone/iam/terraform.tfstate`, `aws-landing-zone/networking/terraform.tfstate`, `aws-landing-zone/kubernetes/terraform.tfstate` (confirmed from each module's `backend.tf`), all in bucket `vschiavo-home-terraform-state`. The current step scans and deletes **every** row in the shared `terraform-state-lock` table — this can delete a lock legitimately held by a concurrent, unrelated run. Fix: delete only the specific `LockID`s for the phases this run actually destroyed (always `kubernetes`; also `networking` and `iam` when `scope == 'all'`).

- [ ] **Step 1: Replace the blanket scan-and-delete with targeted deletes**

Replace:
```yaml
      - name: Clear Terraform Locks
        run: |
          echo "🔓 Clearing any stuck Terraform locks..."
          
          LOCKS=$(aws dynamodb scan \
            --table-name terraform-state-lock \
            --region ${{ env.AWS_REGION }} \
            --query "Items[*].LockID.S" \
            --output text 2>/dev/null || echo "")
          
          if [ ! -z "$LOCKS" ]; then
            echo "$LOCKS" | tr '\t' '\n' | while read LOCK_ID; do
              if [ ! -z "$LOCK_ID" ]; then
                echo "  Clearing lock: $LOCK_ID"
                aws dynamodb delete-item \
                  --table-name terraform-state-lock \
                  --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}" \
                  --region ${{ env.AWS_REGION }} || true
              fi
            done
          fi
          
          echo "  ✅ Locks cleared"
```
with:
```yaml
      - name: Clear Terraform Locks
        run: |
          echo "🔓 Clearing locks for the state keys this run destroyed..."
          
          BUCKET="vschiavo-home-terraform-state"
          LOCK_IDS=("$BUCKET/aws-landing-zone/kubernetes/terraform.tfstate")
          
          if [ "${{ github.event.inputs.scope }}" == "all" ]; then
            LOCK_IDS+=("$BUCKET/aws-landing-zone/networking/terraform.tfstate")
            LOCK_IDS+=("$BUCKET/aws-landing-zone/iam/terraform.tfstate")
          fi
          
          for LOCK_ID in "${LOCK_IDS[@]}"; do
            echo "  Clearing lock (if present): $LOCK_ID"
            aws dynamodb delete-item \
              --table-name terraform-state-lock \
              --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}" \
              --region ${{ env.AWS_REGION }} || true
          done
          
          echo "  ✅ Locks cleared for this run's own state keys only"
```

- [ ] **Step 2: Verify**

Run: `actionlint .github/workflows/destroy-infrastructure.yml`
Expected: no new findings beyond the pre-existing baseline (same check as Task C.1 Step 3).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/destroy-infrastructure.yml
git commit -m "fix: scope Clear Terraform Locks to this run's own state keys

The previous version scanned and deleted every row in the shared
terraform-state-lock DynamoDB table after every destroy run,
including locks legitimately held by concurrent, unrelated runs."
```

### Task C.3: Open PR, wait for checks, merge

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin fix/destroy-infrastructure-safety
gh pr create --repo Vitorspk/aws-landing-zone \
  --title "fix: destroy-infrastructure.yml safety (confirmation gate + scoped lock clearing)" \
  --body "Two independent safety fixes to the most destructive workflow in the repo: (1) it previously had zero confirmation gate before destroying — a scope choice, but no typed confirmation at all — now requires typing DESTROY, matching azure-landing-zone's pattern. (2) its final cleanup step unconditionally deleted every row in the shared terraform-state-lock DynamoDB table, which could clobber a lock held by an unrelated concurrent run — now only clears the specific state-key locks this run's own destroyed phases used. Part of the post-azure-landing-zone hardening pass."
```

- [ ] **Step 2: Wait for checks, then squash-merge**

```bash
gh pr merge --repo Vitorspk/aws-landing-zone --squash --delete-branch <PR-number>
```

---

## PR D — CI/CD hardening

**Branch:** `chore/ci-hardening`

### Task D.1: Add `concurrency:` groups to all 4 operational workflows

**Files:**
- Modify: `.github/workflows/deploy-infrastructure.yml`
- Modify: `.github/workflows/destroy-infrastructure.yml`
- Modify: `.github/workflows/deploy-ingress-nginx.yml`
- Modify: `.github/workflows/destroy-ingress-nginx.yml`

**Note:** None of the 7 workflows in this repo has a `concurrency:` block. Use a **constant** group name per logical resource pair (not interpolated from an input) — this is the exact lesson learned from `azure-landing-zone`'s final review: a group keyed by `phase=all` vs `phase=kubernetes`, or `clusters=all` vs `clusters=dev`, does not actually serialize two overlapping-scope runs, since they land in different group strings. `deploy-infrastructure.yml` and `destroy-infrastructure.yml` share one group (`deploy-infrastructure`) so a deploy and a destroy queue behind each other instead of racing the same Terraform state; the two ingress workflows share `ingress` for the same reason.

- [ ] **Step 1: Add to `deploy-infrastructure.yml`**

Right after the `on:` block (before `env:`), add:
```yaml
concurrency:
  group: deploy-infrastructure
  cancel-in-progress: false
```

- [ ] **Step 2: Add to `destroy-infrastructure.yml`**

Right after the `on:` block (before `env:`), add:
```yaml
concurrency:
  group: deploy-infrastructure
  cancel-in-progress: false
```

- [ ] **Step 3: Add to `deploy-ingress-nginx.yml`**

Right after the `env:` block (before `jobs:`), add:
```yaml
concurrency:
  group: ingress
  cancel-in-progress: false
```

- [ ] **Step 4: Add to `destroy-ingress-nginx.yml`**

Right after the `env:` block (before `jobs:`), add:
```yaml
concurrency:
  group: ingress
  cancel-in-progress: false
```

- [ ] **Step 5: Verify**

Run: `actionlint .github/workflows/deploy-infrastructure.yml .github/workflows/destroy-infrastructure.yml .github/workflows/deploy-ingress-nginx.yml .github/workflows/destroy-ingress-nginx.yml`
Expected: no new findings.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/deploy-infrastructure.yml .github/workflows/destroy-infrastructure.yml .github/workflows/deploy-ingress-nginx.yml .github/workflows/destroy-ingress-nginx.yml
git commit -m "ci: add concurrency groups so deploy/destroy workflows can't race the same state or cluster"
```

### Task D.2: Add `checkov` (report-only) to `terraform-ci.yml`

**Files:**
- Modify: `.github/workflows/terraform-ci.yml`

- [ ] **Step 1: Add the job**

Add as a new top-level job, sibling to `validate` (after it):
```yaml
  security-scan:
    name: Checkov Security Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Checkov
        uses: bridgecrewio/checkov-action@v12
        continue-on-error: true
        with:
          directory: terraform/
          compact: true
          quiet: true
```

- [ ] **Step 2: Verify locally**

Run: `checkov -d terraform/ --compact --quiet`
Expected: `CKV_AWS_39`/`CKV_AWS_38` no longer appear in the failed list (skipped, per PR B Task B.2). The remaining ~26 findings (IAM policy wildcard/write-access warnings, CloudWatch log retention/encryption, security-group egress-all, public-IP-on-subnet) are expected and intentionally left as non-blocking CI visibility — none are fixed in this plan.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/terraform-ci.yml
git commit -m "ci: add checkov security scan (report-only) to terraform-ci workflow"
```

### Task D.3: Pin unpinned tool versions

**Files:**
- Modify: `.github/workflows/terraform-ci.yml` (`tflint_version: latest`)
- Modify: `.github/workflows/deploy-ingress-nginx.yml` (`azure/setup-kubectl@v4` `version: 'latest'`)
- Modify: `.github/workflows/destroy-ingress-nginx.yml` (`azure/setup-kubectl@v4` `version: 'latest'`)

- [ ] **Step 1: Pin tflint in `terraform-ci.yml`**

Replace:
```yaml
      - name: Setup tflint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: latest
```
with:
```yaml
      - name: Setup tflint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: v0.64.0
```

- [ ] **Step 2: Pin kubectl in both ingress workflows**

In both `deploy-ingress-nginx.yml` and `destroy-ingress-nginx.yml`, replace:
```yaml
      - name: Setup kubectl
        uses: azure/setup-kubectl@v4
        with:
          version: 'latest'
```
with:
```yaml
      - name: Setup kubectl
        uses: azure/setup-kubectl@v4
        with:
          version: 'v1.36.3'
```
(`v1.36.3` is the current upstream stable release, confirmed via `curl -s https://dl.k8s.io/release/stable.txt` — same version used on the `azure-landing-zone` pass, since both repos run the same Kubernetes minor version.)

- [ ] **Step 3: Verify**

Run: `actionlint .github/workflows/terraform-ci.yml .github/workflows/deploy-ingress-nginx.yml .github/workflows/destroy-ingress-nginx.yml`
Expected: no new findings.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/terraform-ci.yml .github/workflows/deploy-ingress-nginx.yml .github/workflows/destroy-ingress-nginx.yml
git commit -m "fix: pin tflint and kubectl versions (were both 'latest')"
```

### Task D.4: Constrain the free-form destroy confirmation, reconcile the two `.tflint.hcl` files

**Files:**
- Modify: `.github/workflows/destroy-ingress-nginx.yml` (the `confirm` input)
- Modify: `terraform/02-kubernetes/.tflint.hcl`

- [ ] **Step 1: Constrain `confirm` to a fixed choice**

Replace:
```yaml
      confirm:
        description: 'Type "yes" to confirm destruction'
        required: true
        type: string
```
with:
```yaml
      confirm:
        description: 'Confirm destruction'
        required: true
        type: choice
        options:
          - 'no'
          - 'yes'
```
The consuming step already does `if [ "${{ github.event.inputs.confirm }}" != "yes" ]; then exit 1; fi` — no change needed there.

- [ ] **Step 2: Reconcile the nested `.tflint.hcl` with the root one**

The root `.tflint.hcl` has `terraform_unused_declarations` enabled and doesn't mention `terraform_required_providers` at all (so it uses tflint's own default, which is enabled); the nested `terraform/02-kubernetes/.tflint.hcl` disables both. Align the nested file to match the root's actual behavior — remove the two rule overrides that make it diverge for no stated functional reason. In `terraform/02-kubernetes/.tflint.hcl`, replace:
```hcl
# Ignore specific rules that may cause issues
rule "terraform_unused_declarations" {
  enabled = false  # Disable to avoid false positives
}

rule "terraform_required_providers" {
  enabled = false  # We have the providers configured
}

rule "terraform_deprecated_interpolation" {
```
with:
```hcl
# Ignore specific rules that may cause issues
rule "terraform_deprecated_interpolation" {
```

- [ ] **Step 3: Verify tflint still runs clean on `02-kubernetes` with the reconciled config**

```bash
cd terraform/02-kubernetes && tflint --init && tflint -f compact
```
Expected: no new findings (if `terraform_unused_declarations` now flags something real, that's a genuine finding worth fixing in this same task — inspect and fix it if so, since this plan already checked `02-kubernetes/variables.tf`/`main.tf` don't have obviously-unused declarations in prior tasks).

- [ ] **Step 4: Verify the workflow YAML**

Run: `actionlint .github/workflows/destroy-ingress-nginx.yml`
Expected: no new findings.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/destroy-ingress-nginx.yml terraform/02-kubernetes/.tflint.hcl
git commit -m "fix: constrain destroy-ingress-nginx confirm input to a fixed choice; reconcile tflint configs"
```

### Task D.5: Open PR, wait for checks, merge

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin chore/ci-hardening
gh pr create --repo Vitorspk/aws-landing-zone \
  --title "ci: concurrency groups, checkov, pinned tool versions, constrained destroy confirmation" \
  --body "Adds concurrency groups to all 4 operational workflows (constant group names, not interpolated from inputs — the exact bug found and fixed in azure-landing-zone's final review). Adds checkov (report-only) to terraform-ci.yml. Pins tflint and kubectl (both were 'latest'). Constrains destroy-ingress-nginx.yml's confirm input to a fixed choice instead of free text. Reconciles the two .tflint.hcl files' diverging rule overrides. Part of the post-azure-landing-zone hardening pass."
```

- [ ] **Step 2: Wait for checks (including the new checkov job actually running), then squash-merge**

```bash
gh pr merge --repo Vitorspk/aws-landing-zone --squash --delete-branch <PR-number>
```

---

## PR E — Makefile

**Branch:** `fix/makefile-broken-targets`

### Task E.1: Repoint or remove targets that call nonexistent scripts

**Files:**
- Modify: `Makefile`

**Note:** Confirmed via `ls scripts/`: only `activate-ssl-certificate.sh`, `deploy-ingress-controllers.sh`, `force-delete-all.sh`, `format-terraform.sh`, `pre-deployment-check.sh` exist. The Makefile references `check-prerequisites.sh`, `setup-backend.sh`, `cleanup-resources.sh`, `complete-reset.sh`, `cleanup-k8s-jobs.sh` — none of which exist. `apply-all` and `destroy-all` both depend on the `cleanup` target, so both are currently broken (`make apply-all` fails immediately with "No such file or directory").

- [ ] **Step 1: Repoint `check` to the real, equivalent script**

Replace:
```makefile
check: ## Check prerequisites (AWS CLI, credentials, backend)
	@chmod +x scripts/check-prerequisites.sh
	@./scripts/check-prerequisites.sh
```
with:
```makefile
check: ## Check prerequisites (AWS CLI, credentials, backend)
	@chmod +x scripts/pre-deployment-check.sh
	@./scripts/pre-deployment-check.sh
```

- [ ] **Step 2: Remove `setup-backend` (no equivalent script exists)**

Delete:
```makefile
setup-backend: ## Setup S3 bucket and DynamoDB table
	@chmod +x scripts/setup-backend.sh
	@./scripts/setup-backend.sh
```

- [ ] **Step 3: Remove `cleanup` and `cleanup-k8s` (no equivalent scripts exist), and drop them from `apply-all`/`destroy-all`**

Delete:
```makefile
cleanup: ## Cleanup conflicting CloudWatch log groups and K8s jobs
	@chmod +x scripts/cleanup-resources.sh
	@./scripts/cleanup-resources.sh

reset: ## Complete reset - destroy all infrastructure
	@chmod +x scripts/complete-reset.sh
	@./scripts/complete-reset.sh

cleanup-k8s: ## Cleanup Kubernetes jobs only
	@chmod +x scripts/cleanup-k8s-jobs.sh
	@./scripts/cleanup-k8s-jobs.sh
```
Replace with (repointing `reset` to the real, closest-equivalent script instead of deleting it):
```makefile
reset: ## Complete reset - destroy all infrastructure (interactive confirmation)
	@chmod +x scripts/force-delete-all.sh
	@./scripts/force-delete-all.sh
```

- [ ] **Step 4: Drop the now-removed `cleanup` dependency from `apply-all`/`destroy-all`**

Replace:
```makefile
apply-all: cleanup apply-iam apply-networking apply-kubernetes ## Apply all phases sequentially with cleanup
```
with:
```makefile
apply-all: apply-iam apply-networking apply-kubernetes ## Apply all phases sequentially
```

Replace:
```makefile
destroy-all: destroy-kubernetes destroy-networking destroy-iam cleanup ## Destroy all phases in reverse order
```
with:
```makefile
destroy-all: destroy-kubernetes destroy-networking destroy-iam ## Destroy all phases in reverse order
```

- [ ] **Step 5: Update the `.PHONY` line**

Replace:
```makefile
.PHONY: help init plan apply destroy cleanup reset validate format
```
with:
```makefile
.PHONY: help check init plan apply-iam apply-networking apply-kubernetes apply-all destroy-kubernetes destroy-networking destroy-iam destroy-all reset validate format outputs state-list clusters
```
(The original line was already incomplete/stale relative to the real target list — e.g. it named a bare `apply`/`destroy` that don't exist as targets at all, only `apply-iam`/`apply-networking`/etc. This corrects it to the actual current target names.)

- [ ] **Step 6: Verify**

```bash
make help
```
Expected: prints the help text with no error, and no longer lists `cleanup`/`cleanup-k8s`/`setup-backend` (removed) while still listing `check`/`reset` (repointed) and everything else unchanged.

```bash
grep -c "scripts/check-prerequisites.sh\|scripts/setup-backend.sh\|scripts/cleanup-resources.sh\|scripts/complete-reset.sh\|scripts/cleanup-k8s-jobs.sh" Makefile
```
Expected: `0` (no more references to nonexistent scripts anywhere in the file).

- [ ] **Step 7: Commit**

```bash
git add Makefile
git commit -m "fix: remove Makefile targets that call nonexistent scripts

apply-all and destroy-all were both broken (depended on a 'cleanup'
target calling scripts/cleanup-resources.sh, which doesn't exist).
Repoints check -> pre-deployment-check.sh and reset ->
force-delete-all.sh (the real, equivalent scripts); removes
setup-backend/cleanup/cleanup-k8s entirely (no equivalent scripts
exist and they aren't required for apply/destroy to function)."
```

### Task E.2: Open PR, wait for checks, merge

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin fix/makefile-broken-targets
gh pr create --repo Vitorspk/aws-landing-zone \
  --title "fix: remove Makefile targets that call nonexistent scripts" \
  --body "make apply-all and make destroy-all were both broken — they depend on a cleanup target that calls scripts/cleanup-resources.sh, which doesn't exist in the repo (confirmed: only pre-deployment-check.sh, force-delete-all.sh, format-terraform.sh, deploy-ingress-controllers.sh, and activate-ssl-certificate.sh actually exist). Repoints check -> pre-deployment-check.sh and reset -> force-delete-all.sh; removes setup-backend/cleanup/cleanup-k8s entirely rather than writing new scripts (out of scope for this pass per the design spec). Part of the post-azure-landing-zone hardening pass."
```

- [ ] **Step 2: Wait for checks, then squash-merge**

```bash
gh pr merge --repo Vitorspk/aws-landing-zone --squash --delete-branch <PR-number>
```

---

## PR F — Documentation freshness

**Branch:** `docs/refresh-stale-references`

**Precondition:** PR B, D, and E must already be merged (this PR documents their end state).

### Task F.1: Unify the CIDR scheme in `README.md`

**Files:**
- Modify: `README.md:189-196`

**Note:** The real Terraform (`terraform/01-networking/variables.tf` + `main.tf`) uses VPC CIDR `192.168.0.0/16`; each environment's private subnets are carved from a per-env `/20` (`environments` variable: dev `192.168.0.0/20`, stg `192.168.16.0/20`, prd `192.168.32.0/20`, sdx `192.168.48.0/20`), each further split into two `/21`s (one per AZ) via `cidrsubnet(var.environments[env].cidr_block, 1, idx)`. There is no separate "Pods CIDR"/"Services CIDR" concept anywhere in this Terraform (no VPC-CNI custom networking / secondary CIDR is configured) — the README's existing table has those two columns, but they don't correspond to anything real; drop them rather than inventing values.

- [ ] **Step 1: Replace the table**

Replace:
```markdown
## Environments

| Environment | Cluster | Subnet CIDR | Pods CIDR | Services CIDR |
|-------------|---------|-------------|-----------|---------------|
| Development | eks-dev | 10.10.0.0/19 | 10.11.0.0/16 | 10.12.0.0/16 |
| Staging | eks-stg | 10.13.0.0/19 | 10.14.0.0/16 | 10.15.0.0/16 |
| Production | eks-prd | 10.16.0.0/19 | 10.17.0.0/16 | 10.18.0.0/16 |
| Sandbox | eks-sdx | 10.19.0.0/19 | 10.20.0.0/16 | 10.21.0.0/16 |
```
with:
```markdown
## Environments

VPC CIDR: `192.168.0.0/16`. Each environment gets a `/20` private-subnet allocation, split into two `/21`s across 2 availability zones.

| Environment | Cluster | Private Subnet CIDR (/20) |
|-------------|---------|---------------------------|
| Development | eks-dev | 192.168.0.0/20 |
| Staging | eks-stg | 192.168.16.0/20 |
| Production | eks-prd | 192.168.32.0/20 |
| Sandbox | eks-sdx | 192.168.48.0/20 |

Public subnets (shared across all environments, one per AZ): `192.168.192.0/20`, `192.168.208.0/20`.
```

- [ ] **Step 2: Commit is deferred to Task F.5 (all doc edits land in one commit per file touched — see that task for the full list)**

### Task F.2: Unify the CIDR scheme and endpoint claim in `docs/ARCHITECTURE.md`

**Files:**
- Modify: `docs/ARCHITECTURE.md` (ASCII diagram around lines 10-46, table at lines 91-103, line 210)

- [ ] **Step 1: Fix the ASCII diagram's VPC/subnet CIDR labels**

Find and replace each of these exact strings (the diagram's box-drawing characters around them must stay intact — only the CIDR text inside changes):
- `VPC (10.0.0.0/8)` → `VPC (192.168.0.0/16)`
- `10.0.0.0/24` → `192.168.192.0/20` (first occurrence, public subnet AZ1)
- `10.0.1.0/24` → `192.168.208.0/20` (second occurrence, public subnet AZ2)
- `10.10.0.0/19` → `192.168.0.0/21` (dev AZ1)
- `10.10.32.0/19` → `192.168.8.0/21` (dev AZ2)
- `10.13.0.0/19` → `192.168.16.0/21` (stg AZ1)
- `10.13.32.0/19` → `192.168.24.0/21` (stg AZ2)
- `10.16.0.0/19` → `192.168.32.0/21` (prd AZ1)
- `10.16.32.0/19` → `192.168.40.0/21` (prd AZ2)
- `10.19.0.0/19` → `192.168.48.0/21` (sdx AZ1)
- `10.19.32.0/19` → `192.168.56.0/21` (sdx AZ2)

- [ ] **Step 2: Fix the "CIDR Block" summary line and the subnet table**

Replace:
```markdown
- **CIDR Block**: 10.0.0.0/8
```
with:
```markdown
- **CIDR Block**: 192.168.0.0/16
```

Replace:
```markdown
| Public | Shared | 10.0.0.0/24 | 10.0.1.0/24 | NAT Gateways, Load Balancers |
| Private | DEV | 10.10.0.0/19 | 10.10.32.0/19 | EKS nodes, pods, services |
| Private | STG | 10.13.0.0/19 | 10.13.32.0/19 | EKS nodes, pods, services |
| Private | PRD | 10.16.0.0/19 | 10.16.32.0/19 | EKS nodes, pods, services |
| Private | SDX | 10.19.0.0/19 | 10.19.32.0/19 | EKS nodes, pods, services |
```
with:
```markdown
| Public | Shared | 192.168.192.0/20 | 192.168.208.0/20 | NAT Gateways, Load Balancers |
| Private | DEV | 192.168.0.0/21 | 192.168.8.0/21 | EKS nodes, pods, services |
| Private | STG | 192.168.16.0/21 | 192.168.24.0/21 | EKS nodes, pods, services |
| Private | PRD | 192.168.32.0/21 | 192.168.40.0/21 | EKS nodes, pods, services |
| Private | SDX | 192.168.48.0/21 | 192.168.56.0/21 | EKS nodes, pods, services |
```

- [ ] **Step 3: Correct the "Private API Endpoint" line (now that PR B is merged)**

Replace:
```markdown
- **Private API Endpoint**: Optionally restrict API access
```
with:
```markdown
- **API Endpoint**: Public by default (`public_access_cidrs` defaults to `0.0.0.0/0`) so CI (`deploy-ingress-nginx.yml`, running on GitHub-hosted runners) can reach the cluster — configurable per the `eks-cluster` module's `public_access_cidrs` variable if you have a stable IP/VPN to restrict it to
```

- [ ] **Step 4: Commit is deferred to Task F.5**

### Task F.3: Correct the "private cluster" claims in `README.md` and `docs/SECURITY.md`

**Files:**
- Modify: `README.md:202, 239`
- Modify: `docs/SECURITY.md:183-190`

- [ ] **Step 1: Fix `README.md:202`**

Replace:
```markdown
- ✅ Private EKS clusters with IRSA (IAM Roles for Service Accounts)
```
with:
```markdown
- ✅ EKS clusters with IRSA (IAM Roles for Service Accounts); API endpoint is public by default (configurable, see docs/ARCHITECTURE.md)
```

- [ ] **Step 2: Fix `README.md:239`**

Replace:
```markdown
- Private EKS clusters (API endpoint not publicly accessible)
```
with:
```markdown
- EKS worker nodes in private subnets; the API endpoint itself is public by default so CI can reach it, with `public_access_cidrs` configurable per cluster if you need to restrict it
```

- [ ] **Step 3: Fix `docs/SECURITY.md:183-190`**

Read the surrounding context first (`docs/SECURITY.md` lines 180-195) to match its exact heading style, then replace the section that currently asserts:
```markdown
### Private EKS Clusters

This project uses private EKS clusters by default:

- API endpoint not publicly accessible
- Worker nodes in private subnets
```
with:
```markdown
### EKS Cluster Network Access

- Worker nodes run in private subnets.
- The API endpoint's public access is **enabled by default** (`public_access_cidrs = ["0.0.0.0/0"]`) so `deploy-ingress-nginx.yml` can reach the cluster from GitHub-hosted runners. This is configurable via the `eks-cluster` module's `public_access_cidrs` variable — restrict it to a specific CIDR if you have a stable IP or VPN, but note that doing so will break the current CI-based ingress deployment unless you also add a self-hosted runner inside the VPC.
```
(Keep whatever comes immediately after this section in the file unchanged — only replace the heading and the 2-3 lines under it that make the false "private by default" claim.)

- [ ] **Step 4: Commit is deferred to Task F.5**

### Task F.4: Remove `docs/PROJECT_SUMMARY.md`, fix broken references

**Files:**
- Delete: `docs/PROJECT_SUMMARY.md`
- Modify: `README.md:323` (dead `CONTRIBUTING.md` link)
- Modify: `docs/DEPLOYMENT.md:160-175, 257` (references to Makefile targets that don't exist, post-PR-E)

- [ ] **Step 1: Delete the stale template**

```bash
git rm docs/PROJECT_SUMMARY.md
```

- [ ] **Step 2: Remove the dead `CONTRIBUTING.md` link**

In `README.md`, replace:
```markdown
See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.
```
with:
```markdown
Open a PR against `master` — CI (`terraform-ci.yml`) and the automated Claude Code review must pass before merging.
```

- [ ] **Step 3: Fix the Makefile target references in `docs/DEPLOYMENT.md`**

Read `docs/DEPLOYMENT.md` lines 154-180 first to see the exact current "Using Makefile" section structure, then replace the invocation list so it matches the real (post-PR-E) target names — no `make fmt` (real target is `make format`), no `make init-iam`/`make plan-iam`/`make plan-networking`/`make plan-kubernetes` (the real Makefile has one combined `make init` and one combined `make plan` for all phases, plus per-phase `make apply-iam`/`make apply-networking`/`make apply-kubernetes`). Replace:
```markdown
make fmt
```
```markdown
make init-iam
make init-networking
make init-kubernetes
```
```markdown
make plan-iam
make plan-networking
make plan-kubernetes
```
```markdown
make apply-iam
make apply-networking
make apply-kubernetes
```
with, respectively:
```markdown
make format
```
```markdown
make init
```
```markdown
make plan
```
```markdown
make apply-iam
make apply-networking
make apply-kubernetes
```
(The last block is already correct — those three targets do exist — leave it as-is if found unchanged; the fix is only for the four sets of nonexistent per-phase `init-*`/`plan-*`/`fmt` invocations.)

- [ ] **Step 4: Commit is deferred to Task F.5**

### Task F.5: Final commit, open PR, wait for checks, merge

- [ ] **Step 1: Verify no other file references the deleted doc or the fixed claims**

```bash
grep -rn "PROJECT_SUMMARY" --include="*.md" .
grep -rln "10\.0\.0\.0/8\|10\.10\.0\.0/19\|10\.13\.0\.0/19\|10\.16\.0\.0/19\|10\.19\.0\.0/19" --include="*.md" .
grep -rn "Private EKS clusters\|API endpoint not publicly accessible" --include="*.md" .
```
Expected: no matches for any of the three greps (confirms nothing still references the deleted file or the old CIDR/private-endpoint claims).

- [ ] **Step 2: Commit everything from F.1-F.4**

```bash
git add README.md docs/ARCHITECTURE.md docs/SECURITY.md docs/DEPLOYMENT.md docs/PROJECT_SUMMARY.md
git commit -m "docs: unify CIDR scheme with real Terraform, correct private-cluster claims, remove stale PROJECT_SUMMARY.md

README/ARCHITECTURE previously described three mutually-inconsistent
CIDR schemes, none matching the actual 192.168.0.0/16-based Terraform.
README/SECURITY.md claimed EKS clusters are private by default; the
API endpoint's public_access_cidrs is actually 0.0.0.0/0 (now
configurable per PR #<B-number>, still open by default so CI keeps
working). docs/PROJECT_SUMMARY.md was a never-completed template
(placeholder authors, stale version, references to files/scripts that
don't exist) redundant with ARCHITECTURE.md — deleted rather than
maintained as a second source of truth. Also fixes a dead
CONTRIBUTING.md link and DEPLOYMENT.md's references to Makefile
targets that don't exist (make fmt, make init-iam, make plan-iam,
etc. -- the real targets are make format/make init/make plan, fixed
in PR #<E-number>)."
```

- [ ] **Step 3: Push and open the PR**

```bash
git push -u origin docs/refresh-stale-references
gh pr create --repo Vitorspk/aws-landing-zone \
  --title "docs: refresh stale CIDR/endpoint claims, remove PROJECT_SUMMARY.md" \
  --body "Unifies three mutually-inconsistent CIDR schemes across README.md and docs/ARCHITECTURE.md with the real Terraform (192.168.0.0/16-based); corrects README.md/docs/SECURITY.md's false 'private cluster' claims now that the EKS public endpoint is configurable (PR #<B-number>); deletes docs/PROJECT_SUMMARY.md (never-completed template, redundant with ARCHITECTURE.md); fixes a dead CONTRIBUTING.md link and DEPLOYMENT.md's references to Makefile targets that don't exist. Final content PR of the post-azure-landing-zone hardening pass."
```

- [ ] **Step 4: Wait for checks, then squash-merge**

```bash
gh pr merge --repo Vitorspk/aws-landing-zone --squash --delete-branch <PR-number>
```

---

## PR G — `CLAUDE.md` + `.claude/settings.json`

**Branch:** `docs/claude-md-model-tiers`

### Task G.1: Add `.claude/settings.json`

**Files:**
- Create: `.claude/settings.json` (git-ignored — verify with `git check-ignore .claude/settings.json` before creating; if `.claude/` isn't already gitignored here, add it to `.gitignore` first, matching the sibling repos' convention)

- [ ] **Step 1: Check `.claude/` is gitignored**

Run: `git check-ignore .claude/settings.json`
Expected: prints `.claude/settings.json` (confirms it's ignored) — if this prints nothing (exit code 1), add a `.claude/` line to `.gitignore` first and commit that separately before proceeding.

- [ ] **Step 2: Create the file**

```json
{
  "model": "sonnet"
}
```

- [ ] **Step 3: No commit needed for this file (it's gitignored, local-only) — proceed to Task G.2**

### Task G.2: Add `CLAUDE.md`

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Write the file**

```markdown
# CLAUDE.md — AWS Landing Zone

Instructions for AI assistants (Claude Code, @claude in PRs, etc.) working on this repository.

---

## Project overview

Terraform Infrastructure-as-Code for an AWS landing zone (Vitorspk/aws-landing-zone), deployed via GitHub Actions. Sibling repo to `azure-landing-zone` — same phased structure, same tooling conventions, ported over in a 2026-08-11 hardening pass.

- Three ordered Terraform modules: `terraform/00-iam` (IAM roles/policies, IRSA for AWS LB Controller + EBS CSI) → `terraform/01-networking` (VPC, public/private subnets, NAT Gateways, security groups, flow logs, VPC endpoints) → `terraform/02-kubernetes` (4 EKS clusters: dev/stg/prd/sdx, selectable via `deploy_clusters`)
- Remote state: S3 (`vschiavo-home-terraform-state`) + DynamoDB lock table (`terraform-state-lock`) — see each module's `backend.tf`. Modules link to each other via `data "terraform_remote_state"`, not Terraform workspaces.
- Ingress (NGINX) is deployed separately from Terraform, via `deploy-ingress-nginx.yml` + `kubectl` against the manifests in `manifests/`
- `terraform/02-kubernetes/modules/eks-cluster` is the only local module; the root module instantiates it 4 times (one `module` block per environment), not via `for_each`

---

## Rules

### Git workflow (mandatory)

- **Never commit directly to `master`**
- Always branch: `git checkout -b <type>/<description>` from `master` (types: `fix/`, `feat/`, `chore/`, `docs/`)
- Push branch, open PR with `gh pr create`, wait for CI green, squash-merge
- PRs run `terraform-ci.yml` (fmt/validate/tflint, blocking + checkov, report-only) plus automated Claude Code Review — fix everything the review flags before merging

### Security

- **Never commit `.tfvars` or `.tfstate` files** — only `terraform.tfvars.example` files are tracked. This repo's git history has commit messages referencing a past `.tfvars` removal (`660e1a0`, `f13129a`) — treat any diff touching `.tfvars`/`.tfstate`/`.terraform/` as a stop-and-check moment.
- AWS credentials come from GitHub Secrets (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`) — never hardcoded.
- The EKS API server's public endpoint (`public_access_cidrs`) defaults to `0.0.0.0/0` **on purpose** — `deploy-ingress-nginx.yml` runs `kubectl` from GitHub-hosted runners outside the VPC and needs to reach it. Do not "fix" this by restricting the default without first setting up a self-hosted runner inside the VPC or a VPN — you'll break ingress deployment. If you need a more restrictive default, discuss it with the user first.

### Terraform variables

- **Every variable must have either a `default` or a value supplied by CI** (`-var`, `-var-file`, or `TF_VAR_*`). A required variable with no value source doesn't fail fast in GitHub Actions — Terraform blocks on an interactive prompt that never resolves on a non-interactive runner, hanging for hours while holding the state lock. This exact bug hit the sibling `azure-landing-zone` repo (missing default on a required variable) and this repo had the identical latent pattern (`region` with no default in all 3 root modules) before the 2026-08-11 hardening pass fixed it.
- Prefer `validation` blocks on variables with a constrained value set (see `deploy_clusters` for the pattern).
- `terraform.tfvars.example` must match the real variable's type — a past bug here had `deploy_clusters` documented as a map while the variable is a string, which fails `terraform plan` with a type error if copied verbatim.

### CI/workflow conventions

- Every `workflow_dispatch` operational workflow must have a `concurrency:` group that actually prevents two invocations from racing the same state/cluster — use a **constant** group name, not one interpolated from an input, unless every possible input value is guaranteed disjoint. An interpolated key silently fails to serialize `phase=all` against `phase=kubernetes` (or `clusters=all` against `clusters=dev`).
- `#checkov:skip=<ID>:<reason>` comments only take effect as the **first line inside** the resource block (right after the opening `{`) — placed above the `resource` line, checkov silently ignores it and still reports the finding as failed. When a resource lives in a child module instantiated multiple times (like `eks-cluster`), one skip comment in the module's source file covers every calling instance.
- Any destructive `workflow_dispatch` (destroy/teardown) must require typing an exact confirmation string (e.g. `DESTROY`) as a required `type: string` input, checked in the first step before any AWS calls run.
- A workflow step that clears a shared lock table (DynamoDB, or equivalent) must only delete the specific keys it owns — never blanket-scan-and-delete the whole table, which can clobber a lock held by a concurrent, unrelated run.
- A Makefile target must only reference scripts that actually exist in the repo — `apply-all`/`destroy-all` were broken for a while because they depended on a `cleanup` target calling a script that had never been committed.

---

## Recommended models (Claude Code)

Model selection is **manual** — pick it when launching (`claude --model <alias>`) or switch mid-session with `/model <alias>`. Claude Code does not auto-switch per task; this table is the project convention (same as `azure-landing-zone`/`speedtruck`/`portfolio`):

| Task | Model | Command |
|------|-------|---------|
| Day-to-day work (reviewing plans, small fixes, deploys) | Sonnet | `claude --model sonnet` — **project default** |
| Local iteration / fast feedback | Haiku | `claude --model haiku` |
| Incident diagnosis, security-sensitive changes (IAM/network/EKS endpoint), complex debugging | Opus | `claude --model opus` |
| Architecture design (plan + execute) | opusplan | `claude --model opusplan` — Opus in plan mode, Sonnet on execution |

The day-to-day default (Sonnet) is pinned in `.claude/settings.json` (`"model": "sonnet"`), so it applies automatically when opening Claude Code in this repo. Note: `.claude/` is git-ignored, so this default is local to each contributor's machine.

This tiering is for the **main conversation model** only. When orchestrating subagents (`superpowers:subagent-driven-development`, the `Workflow` tool, or ad-hoc background agents), assign models per task explicitly regardless of the session default — cheap/mechanical Terraform edits on Haiku, judgment-heavy task review on Sonnet, and the final whole-branch review on Opus. That routing already works today with no extra setup; it was used for both this repo's and `azure-landing-zone`'s hardening passes.

---

## Local validation

```bash
make check      # runs scripts/pre-deployment-check.sh
make validate    # terraform validate on all 3 root modules
make format      # terraform fmt -recursive
```

Matches the `terraform-ci.yml` CI gate (fmt + validate + tflint, blocking) minus the `checkov` job (report-only, CI-only) and minus `tflint` itself (not currently a Makefile target — run `tflint -f compact` manually from inside a module directory if you need it locally).

---

## CI workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `terraform-ci.yml` | push/PR touching `terraform/**`, `.github/workflows/**`, `scripts/**` | Blocking: `terraform fmt -check`, `terraform validate`, `tflint` per phase. Separate job, report-only: `checkov` security scan. |
| `deploy-infrastructure.yml` | `workflow_dispatch` | `init`/`plan`/`apply` per phase (`iam`/`networking`/`kubernetes`/`all`), selectable clusters. Concurrency-protected (shares a group with `destroy-infrastructure.yml`). |
| `destroy-infrastructure.yml` | `workflow_dispatch` | Destroys `kubernetes-only` or `all` phases, with extensive AWS-CLI cleanup before/after `terraform destroy`. Requires typing `DESTROY` to confirm. Concurrency-protected (shares a group with `deploy-infrastructure.yml`). Clears only its own state-key locks from the shared DynamoDB lock table, never the whole table. |
| `deploy-ingress-nginx.yml` / `destroy-ingress-nginx.yml` | `workflow_dispatch` | `kubectl`-based ingress-nginx install/removal against selected clusters, external/internal/both. Concurrency-protected (shared `ingress` group between both workflows, so a deploy and a destroy queue behind each other). |
| `claude-code-review.yml` | PR | AI code review, posts feedback as PR comment |
| `claude.yml` | `@claude` mention | On-demand Claude Code in issues/PRs |

---

## What to avoid

- Do not restrict the EKS `public_access_cidrs` default without first replacing GitHub-hosted-runner CI access with something that works from inside the VPC (self-hosted runner, VPN, Direct Connect) — see "Security" above.
- Do not write the 5 shell scripts the pre-2026-08-11 Makefile referenced but never had (`check-prerequisites.sh`, `setup-backend.sh`, `cleanup-resources.sh`, `complete-reset.sh`, `cleanup-k8s-jobs.sh`) without discussing scope first — the hardening pass deliberately simplified the Makefile instead of authoring new automation.
- Do not assume `docs/superpowers/specs/` planning docs are current — they're point-in-time; verify against actual code before relying on a claim from one (the design spec for the 2026-08-11 pass initially assumed `.tflint.hcl` used a generic ruleset; it actually already used `tflint-ruleset-aws`, caught before writing the implementation plan).
```

- [ ] **Step 2: Commit**

`.claude/settings.json` is git-ignored (verified in Step 1) — only `CLAUDE.md` is tracked and committed:
```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md with model-tier convention and project rules

Mirrors azure-landing-zone's CLAUDE.md (same 3-tier model convention),
adapted for this repo's EKS/AWS specifics and the lessons from the
2026-08-11 hardening pass. .claude/settings.json is git-ignored, not
part of this commit."
```

### Task G.3: Open PR, wait for checks, merge

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin docs/claude-md-model-tiers
gh pr create --repo Vitorspk/aws-landing-zone \
  --title "docs: add CLAUDE.md with model-tier convention and project rules" \
  --body "Adds CLAUDE.md, matching the same 3-tier Claude Code model convention already documented in azure-landing-zone/speedtruck/portfolio. Codifies the durable rules from the 2026-08-11 hardening pass: git workflow, .tfvars/.tfstate security, the EKS public-endpoint tradeoff, 'every Terraform variable needs a default or a CI value source', concurrency-group correctness, checkov skip-comment placement, DynamoDB lock-clear scoping, and Makefile-target-must-reference-a-real-script. .claude/settings.json (git-ignored, not part of this PR) pins the day-to-day default to sonnet. Fixes claude-code-review.yml's previously-dangling reference to a CLAUDE.md that didn't exist. Final PR of the post-azure-landing-zone hardening pass."
```

- [ ] **Step 2: Wait for checks, then squash-merge**

```bash
gh pr merge --repo Vitorspk/aws-landing-zone --squash --delete-branch <PR-number>
```

---

## Final verification (after all seven PRs merged)

- [ ] Run `make check && make validate && make format` from repo root on a fresh `git pull` of `master` — all three succeed.
- [ ] Run `checkov -d terraform/ --compact --quiet` — confirm `CKV_AWS_39`/`CKV_AWS_38` show as skipped (not failed), and the total failed-check count only includes the ~26 pre-existing, un-fixed findings from before this pass (no new failures introduced).
- [ ] Open a throwaway PR touching a `terraform/*.tf` file and confirm `Validate Terraform` (tflint step) and `Checkov Security Scan` (report-only) both actually run and report in the PR checks list.
- [ ] `grep -rn "10\.0\.0\.0\|10\.10\.0\.0\|Private EKS clusters\|PROJECT_SUMMARY" --include="*.md" .` from repo root returns nothing.
