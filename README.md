<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# alunduil-infrastructure

Personal infrastructure as code for the `alunduil` GCP project, managed with
Terraform. This repository is the single source of truth for DNS and static
site hosting configuration.

**Repository:** <https://github.com/alunduil/alunduil-infrastructure>
**Author:** Alex Brandt \<<alunduil@gmail.com>\>

## What this manages

- **GCP project** — the `alunduil` project itself (billing, labels)
- **DNS** — `alunduil.com` zone and all records (`blog`, `home`, `groton`, …)
- **Storage** — static website hosting buckets for `blog.alunduil.com`

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
# Option A — local tfvars file (gitignored)
echo 'billing_account_id = "00E1AD-4FD6FE-852B90"' \
  > terraform/alunduil/terraform.local.tfvars

# Option B — environment variable
export TF_VAR_billing_account_id="00E1AD-4FD6FE-852B90"
```

### 3. Initialise Terraform

```bash
cd terraform/alunduil
terraform init
```

### 4. Import existing resources

The `alunduil` project and its DNS records and storage buckets already exist.
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
```

The DNS zone, DNS records, and storage buckets have `import` blocks already
written in [`dns.tf`](terraform/alunduil/dns.tf) and
[`storage.tf`](terraform/alunduil/storage.tf) — they are imported
automatically on the next plan/apply.

### 5. Review and apply

```bash
# Using a local tfvars file:
terraform plan -var-file=terraform.local.tfvars

# Review the plan, then apply:
terraform apply -var-file=terraform.local.tfvars
```

## Day-to-day workflow

1. Create a branch and edit Terraform files under `terraform/alunduil/`
2. Run `terraform plan` locally and review the output
3. Open a pull request against `main` and merge when satisfied
4. Apply manually:

   ```bash
   cd terraform/alunduil
   terraform init
   terraform plan -var-file=terraform.local.tfvars -out=tfplan
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

## Licence

MIT — see [LICENSES/MIT.txt](LICENSES/MIT.txt) or the `SPDX-License-Identifier`
headers on each file.
