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
