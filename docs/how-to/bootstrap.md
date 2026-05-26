<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Run the first-time bootstrap

Stands up CI authentication (Workload Identity Federation, deployer
service accounts, Cloudflare deployer tokens) and populates the GitHub
Actions secrets. Run when starting from scratch or rotating the core
credentials.

## Prerequisites

- The state bucket `alunduil-tfstate` exists — created out-of-band by
  [bootstrap-terraform-state.sh](../../scripts/bootstrap-terraform-state.sh).
- A master Cloudflare API token — see
  [create-master-cloudflare-token.md](create-master-cloudflare-token.md).
- A GitHub App created and installed — see
  [create-github-app.md](create-github-app.md).

## Apply

From `terraform/bootstrap/`:

```sh
gcloud auth application-default login
export TF_VAR_billing_account_id=XXXXXX-XXXXXX-XXXXXX
export CLOUDFLARE_API_TOKEN=...

terraform init
terraform plan
terraform apply
```

## Configure GitHub Actions secrets

```sh
export GH_APP_PRIVATE_KEY="$(cat /path/to/your-app.pem)"
scripts/configure-github-secrets.sh
```

Re-running is a no-op.
