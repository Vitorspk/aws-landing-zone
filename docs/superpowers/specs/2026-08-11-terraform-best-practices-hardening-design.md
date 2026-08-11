# Terraform Best-Practices Hardening — Design

**Date:** 2026-08-11
**Status:** Approved, ready for implementation planning

## Context

Following the same hardening pass already completed on the sibling repo `azure-landing-zone` (see that repo's `docs/superpowers/specs/2026-08-09-terraform-best-practices-hardening-*.md`), a full repository survey of `aws-landing-zone` (Explore agent) covered every Terraform module, all 7 GitHub Actions workflows, every doc file, the Makefile, and all 5 scripts. This spec captures the resulting hardening pass, scoped and prioritized through user Q&A.

`aws-landing-zone` builds an AWS EKS-based landing zone (00-iam → 01-networking → 02-kubernetes, mirroring `azure-landing-zone`'s phased structure) plus a separate ingress-nginx deployment layer. The survey found the same class of issues already fixed on the Azure side, plus several new/worse ones specific to this repo.

## Goals

Fix the concrete issues from the survey, in the categories the user explicitly prioritized (EKS public endpoint exposure, unguarded destroy workflow) plus the same correctness/CI/docs categories already hardened on `azure-landing-zone` — without expanding scope into new infrastructure capability or rewriting working automation.

## Non-goals (explicitly deferred or descoped, by user decision)

- **Fully restricting the EKS public API endpoint** — the current CI (`deploy-ingress-nginx.yml`) runs `kubectl` from GitHub-hosted runners outside the VPC; disabling public access entirely would break CI and requires a bigger architectural change (self-hosted runner inside the VPC, or VPN/Direct Connect). This pass only makes the CIDR **configurable** (currently hardcoded); the default stays open (`0.0.0.0/0`) to avoid breaking CI. Restricting it to a specific CIDR is left for a future pass once the user has a stable IP/VPN to allowlist.
- **Writing the 5 missing shell scripts** the Makefile references (`check-prerequisites.sh`, `setup-backend.sh`, `cleanup-resources.sh`, `complete-reset.sh`, `cleanup-k8s-jobs.sh`) — descoped to a Makefile simplification instead (repoint/remove the broken dependencies) rather than authoring new automation.
- **Rewriting `docs/PROJECT_SUMMARY.md`** — it's a never-completed template (placeholder authors, stale version, references to nonexistent files) redundant with `docs/ARCHITECTURE.md`; deleted rather than rewritten.
- **Monitoring/security-service equivalents** (CloudTrail, AWS Config, GuardDuty) — analogous to `azure-landing-zone`'s deferred Log Analytics/Policy — no new recurring-cost AWS services in this pass.
- **Resolving the ingress-nginx image-pinning inconsistency** (unofficial `kube-webhook-certgen` in the external manifest vs. official digest-pinned image in the internal one) surfaced by git history — real, but outside this Terraform/CI/docs-focused pass; flagged for a future pass.

## Risk tolerance (confirmed with user)

- No live AWS infrastructure currently exists for this repo (everything destroyed or never applied) — every change is verified via `terraform plan`/`validate`/`fmt`, not against a running cluster/VPC.

## Scope: seven themed PRs, in order

Each PR follows the same flow used on `azure-landing-zone`: feature branch → commit per task → `gh pr create` → CI green → squash-merge → delete branch.

### PR A — Terraform correctness

| Change | File(s) | Notes |
|---|---|---|
| Add `default = "sa-east-1"` to `region` | `terraform/00-iam/variables.tf`, `terraform/01-networking/variables.tf`, `terraform/02-kubernetes/variables.tf` | All three declare `region` with no default and no validation — the exact pattern that caused the `azure-landing-zone` incident (a required variable Terraform can't resolve blocks on an interactive prompt that hangs forever on a non-interactive CI runner). Currently masked because every workflow/Makefile target passes `-var="region=..."` explicitly, but an ad-hoc `terraform plan` would hang. `sa-east-1` matches `deploy-infrastructure.yml`'s own hardcoded `AWS_REGION` default, so this doesn't invent a new convention. |
| Add `validation` block to `deploy_clusters` | `terraform/02-kubernetes/variables.tf` | Must be `"all"` or a comma-separated subset of `dev,stg,prd,sdx` — same pattern as the Azure fix. |
| Fix `deploy_clusters` type mismatch in the example tfvars | `terraform/02-kubernetes/terraform.tfvars.example` | The example sets `deploy_clusters` as a map; the variable is declared as a string (default `"all"`). Copying the example verbatim fails `terraform plan` with a type error. Fix the example to the correct string form. |

### PR B — EKS public endpoint

| Change | File(s) | Notes |
|---|---|---|
| Parameterize `public_access_cidrs` | `terraform/02-kubernetes/modules/eks-cluster/variables.tf`, `main.tf` | New variable, default `["0.0.0.0/0"]` (preserves current behavior — CI keeps working). Wire it through from the `02-kubernetes` root module (add a corresponding field, defaulting the same way, to the `clusters` map / a new top-level variable). |

Doc claims ("private cluster") that this change contradicts are corrected in PR F, not here — PR F lands after every code PR so it documents one final, accurate state instead of an intermediate one.

### PR C — `destroy-infrastructure.yml` safety

| Change | File(s) | Notes |
|---|---|---|
| Add a typed confirmation gate | `.github/workflows/destroy-infrastructure.yml` | Currently has a `scope` choice (kubernetes-only/all) but no confirmation step at all before destroying — add a `confirm_destroy` input requiring the literal string `DESTROY`, mirroring `azure-landing-zone`'s `deploy-infrastructure.yml` pattern. |
| Scope down the "Clear Terraform Locks" step | `.github/workflows/destroy-infrastructure.yml` | Currently unconditionally scans and deletes **every** entry in the shared `terraform-state-lock` DynamoDB table after every destroy run — this can clobber a lock legitimately held by a concurrent, unrelated run (e.g. someone else's `deploy-infrastructure` in progress). Fix: only delete the lock entries whose `LockID` matches this run's own state keys (`aws-landing-zone/iam/terraform.tfstate`, `.../networking/...`, `.../kubernetes/...`, filtered to the phases the `scope` input actually destroyed). |

### PR D — CI/CD hardening

| Change | File(s) | Notes |
|---|---|---|
| Add `concurrency:` groups | `deploy-infrastructure.yml`, `destroy-infrastructure.yml`, `deploy-ingress-nginx.yml`, `destroy-ingress-nginx.yml` | None of the 7 workflows has a `concurrency:` block today. Use a **constant** group name per logical resource (e.g. `group: deploy-infrastructure` for both the deploy and destroy infra workflows sharing one name so they queue behind each other; `group: ingress` shared between the two ingress workflows) — not one interpolated from an input value, which was the exact bug found and fixed in `azure-landing-zone`'s final review (a group keyed by `module=all` vs `module=02-kubernetes`, or `clusters=all` vs `clusters=dev`, doesn't actually serialize overlapping-scope runs). |
| Add `checkov` (report-only) | `.github/workflows/terraform-ci.yml` | New job, `continue-on-error: true`, same pattern as Azure. Checkov is multi-cloud, so the same tool applies; no AWS-specific skip is anticipated but add one inline if the scan surfaces the intentionally-open `public_access_cidrs` default from PR B (mirroring how the Azure pass handled its equivalent accepted-risk finding). |
| Switch to the AWS tflint ruleset | `.tflint.hcl` (root and the nested `terraform/02-kubernetes/.tflint.hcl`) | Add `tflint-ruleset-aws` (the AWS-specific plugin, analogous to `tflint-ruleset-azurerm` used on the Azure repo) alongside the existing `terraform` plugin. Also reconcile the two `.tflint.hcl` files so `terraform_unused_declarations` isn't inconsistently enabled/disabled between the repo root and `02-kubernetes`. |
| Pin unpinned tool versions | `terraform-ci.yml` (`tflint_version: latest`), `deploy-ingress-nginx.yml` and `destroy-ingress-nginx.yml` (`azure/setup-kubectl@v4` `version: 'latest'`) | Same fix as the Azure pass — pin to the current stable release at implementation time (checked via `curl -s https://dl.k8s.io/release/stable.txt`, same as before). |
| Constrain the free-form destroy confirmation | `destroy-ingress-nginx.yml` | `confirm` is currently `type: string` (must type "yes"), the same script-injection-shaped anti-pattern already fixed on the Azure side. Change to `type: choice` with options `no`/`yes`; no change needed to the consuming shell check. |

### PR E — Makefile

| Change | File(s) | Notes |
|---|---|---|
| Remove dependencies on nonexistent scripts | `Makefile` | `check` currently calls `scripts/check-prerequisites.sh` (doesn't exist) — repoint it to the real, equivalent `scripts/pre-deployment-check.sh`. `apply-all`/`destroy-all` depend on `cleanup`/`cleanup-k8s` targets that call `scripts/cleanup-resources.sh`/`scripts/cleanup-k8s-jobs.sh` (neither exists) — remove those two targets from the `apply-all`/`destroy-all` dependency chains (they're optional hygiene steps, not required for apply/destroy to function). `reset` calls `scripts/complete-reset.sh` (doesn't exist) — repoint it to the real, closest-equivalent `scripts/force-delete-all.sh`. `setup-backend` calls `scripts/setup-backend.sh` (doesn't exist, and no close equivalent) — remove the target entirely and document manual backend bootstrap steps (S3 bucket + DynamoDB table) inline in `docs/DEPLOYMENT.md` instead, if not already covered there. |

### PR F — Documentation freshness

Depends on PR B, D, and E landing first (this PR describes their end state).

| Change | File(s) | Notes |
|---|---|---|
| Unify the CIDR scheme | `README.md`, `docs/ARCHITECTURE.md` | Three different, mutually inconsistent CIDR schemes exist today (README's `10.10.0.0/19`-style table, ARCHITECTURE's `10.0.0.0/8`-style table, and the actual Terraform's `192.168.0.0/16`-based scheme). Replace both docs' tables with the real values from `terraform/01-networking/variables.tf`. |
| Correct the "private cluster" claims | `README.md`, `docs/SECURITY.md`, `docs/ARCHITECTURE.md` | Now that PR B makes `public_access_cidrs` configurable (default still open), describe this accurately instead of claiming private-by-default. |
| Remove `docs/PROJECT_SUMMARY.md` | `docs/PROJECT_SUMMARY.md` | Never-completed template, redundant with `ARCHITECTURE.md` — delete rather than maintain two sources of truth. |
| Fix broken references | `README.md` (dead `CONTRIBUTING.md` link), `docs/DEPLOYMENT.md` (references `make fmt`/`make init-iam`/`make plan-iam` etc., none of which exist — the real targets are `make format` and a single combined `make plan`) | Remove the dead link; correct the Makefile target names to match PR E's actual (simplified) target list. |

### PR G — `CLAUDE.md` + `.claude/settings.json`

| Change | File(s) | Notes |
|---|---|---|
| Add the same 3-tier model convention | `.claude/settings.json` (git-ignored, `{"model": "sonnet"}`) | Mirrors `azure-landing-zone`/`speedtruck`/`portfolio`. |
| Add `CLAUDE.md` | `CLAUDE.md` | Same structure as `azure-landing-zone`'s (git workflow, security rules, model tiers), adapted for this repo's specifics: the `region`-default lesson (PR A), the EKS public-endpoint lesson (PR B), the DynamoDB blanket-lock-clear lesson (PR C), the constant-vs-interpolated concurrency-group lesson (PR D), and "a Makefile target must reference a script that actually exists" (PR E). Also fixes `claude-code-review.yml`'s currently-dangling reference to a `CLAUDE.md` that doesn't exist yet. |

## Ordering dependency

PR F depends on PR B, D, and E having merged (it documents their end state). PR G can land any time after PR A-F conceptually, but ordering it last keeps its "lessons learned" section accurate about what actually shipped. PRs A, B, C, D, E are independent of each other and could technically merge in any order; the stated order goes roughly by severity (the two issues the user flagged as priority — B and C — come right after the baseline correctness pass).

## Rollback

Each PR is a small, independently revertible `git revert` if something regresses. None of these changes touch live infrastructure (none currently exists), so there is no apply-side rollback concern for this pass.
