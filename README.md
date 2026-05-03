<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# alunduil-infrastructure

[![License](https://img.shields.io/github/license/alunduil/alunduil-infrastructure)](LICENSES/MIT.txt)

Personal infrastructure as code, managed with Terraform. This repository is
the single source of truth for the `alunduil` GCP project, its DNS, and the
GitHub repositories owned by `alunduil`.

**Repository:** <https://github.com/alunduil/alunduil-infrastructure>
**Author:** Alex Brandt \<<alunduil@gmail.com>\>

## What this manages

- **GCP project** — the `alunduil` project itself (billing, labels,
  foundational APIs)
- **DNS** — `alunduil.com` zone and all records (`blog`, `home`, `groton`, …)
- **GitHub repositories** — settings (visibility, merge rules, discussions, …)
  for repositories owned by `alunduil`, applied via classification
  (`default`, `release-please`, `git-flow`)

All Terraform lives in [`terraform/alunduil/`](terraform/alunduil/). There is
one environment (this is personal homelab infrastructure, equivalent in scope
to a single production project).

## Apply policy

`terraform plan` and `terraform apply` are both run manually. Run `plan`
locally before committing or pushing, and review it before applying.

## Prerequisites

Before you can run anything you need:

- **GCP access** — owner on the `alunduil` project (`alunduil@gmail.com`)
- **`gcloud` CLI** — authenticated with both user and ADC credentials:

  ```bash
  gcloud auth login
  gcloud auth application-default login
  ```

- **Terraform ≥ 1.5** — required for `import` blocks
- **GitHub token** — exported as `GITHUB_TOKEN` with `repo` and
  `delete_repo` scopes. The simplest source is the `gh` CLI:

  ```bash
  export GITHUB_TOKEN="$(gh auth token)"
  ```

## First-time bootstrap

This sequence is only needed once, when setting up from scratch or after a
full disaster recovery.

### 1. Create the state bucket

The GCS bucket that holds Terraform state must exist before `terraform init`
can run:

```bash
bash scripts/bootstrap-terraform-state.sh
```

This creates `alunduil-tfstate` in the `EU` multi-region in the `alunduil`
project with versioning and public access prevention enabled. If the bucket
already exists the script is a no-op.

### 2. Provide the billing account ID

The billing account ID is required but not committed. Create a local vars file
(already gitignored) or export an environment variable:

```bash
# Option A — local tfvars file (gitignored, auto-loaded by terraform)
echo 'billing_account_id = "00E1AD-4FD6FE-852B90"' \
  > terraform/alunduil/terraform.local.auto.tfvars

# Option B — environment variable
export TF_VAR_billing_account_id="00E1AD-4FD6FE-852B90"
```

### 3. Initialise Terraform

```bash
cd terraform/alunduil
terraform init
```

### 4. Import existing resources

The `alunduil` project, its DNS records, and the GitHub repositories listed
in [`terraform.tfvars`](terraform/alunduil/terraform.tfvars) already exist.
Import them so Terraform can manage them without recreating them:

```bash
# The GCP project itself
terraform import google_project.env alunduil

# Foundational APIs (import if project was pre-existing)
terraform import google_project_service.iam \
  alunduil/iam.googleapis.com
terraform import google_project_service.cloudresourcemanager \
  alunduil/cloudresourcemanager.googleapis.com
terraform import google_project_service.serviceusage \
  alunduil/serviceusage.googleapis.com

# Each GitHub repository in terraform.tfvars (repeat for every entry):
terraform import 'github_repository.managed["alunduil-infrastructure"]' \
  alunduil-infrastructure
```

The DNS zone and records have `import` blocks already written in
[`dns.tf`](terraform/alunduil/dns.tf) — they are imported automatically on
the next plan/apply.

### 5. Review and apply

```bash
terraform plan
# Review the plan, then apply:
terraform apply
```

`terraform.local.auto.tfvars` (or `TF_VAR_billing_account_id`) is picked
up automatically — no `-var-file=` needed.

## Day-to-day workflow

1. Create a branch and edit Terraform files under `terraform/alunduil/`
2. Run `terraform plan` locally and review the output
3. Open a pull request against `main` and merge when satisfied
4. Apply manually:

   ```bash
   cd terraform/alunduil
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

## Development environment

Open this repository in VS Code and accept the **Reopen in Container** prompt.
The devcontainer installs `gcloud`, `terraform`, `pre-commit`, and `reuse`
automatically.

After the container starts, authenticate:

```bash
gcloud auth login
gcloud auth application-default login
```

## CI

The `pre-commit` workflow runs every hook in `.pre-commit-config.yaml` on
every pull request and push to `main`. This covers whitespace, YAML and JSON
syntax, Markdown and YAML linting, REUSE compliance, secrets detection, and
`terraform_fmt` / `terraform_validate`.

## Support and contributions

This is personal infrastructure maintained for the author's own use. Issues
and pull requests from outside collaborators are not actively solicited and
may not be triaged.

## Licence

MIT — see [LICENSES/MIT.txt](LICENSES/MIT.txt) or the `SPDX-License-Identifier`
headers on each file.
