<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Run the first-time bootstrap

Stands up CI authentication (Workload Identity Federation, deployer
service accounts, Cloudflare deployer tokens) and populates the GitHub
Actions secrets. Run when starting from scratch or rotating the core
credentials.

## Prerequisites

- A master Cloudflare API token — see
  [create-master-cloudflare-token.md](create-master-cloudflare-token.md).
- A GitHub App created and installed — see
  [create-github-app.md](create-github-app.md).

## Run

```sh
gcloud auth application-default login
export TF_VAR_billing_account_id=XXXXXX-XXXXXX-XXXXXX
export CLOUDFLARE_API_TOKEN=...

just bootstrap
```

`just bootstrap` runs `scripts/bootstrap-terraform-state.sh`, then
`terraform init && terraform apply` against `terraform/bootstrap/`,
then `scripts/configure-github-secrets.sh` — all idempotent, safe to
re-run after a partial failure. The secrets script prompts for the
GitHub App ID and `.pem` path when those aren't already in env vars
(`GH_APP_ID`, `GH_APP_PRIVATE_KEY_FILE`) or set as repo secrets.
