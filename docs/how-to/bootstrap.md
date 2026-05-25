<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# First-time bootstrap

Stand up the CI authentication substrate (Workload Identity Federation,
deployer service accounts, Cloudflare deployer tokens) and populate the
GitHub Actions secrets. Only run when starting from scratch or rotating
the core credentials.

## Prerequisites

- The state bucket `alunduil-tfstate` exists — created out-of-band by
  [bootstrap-terraform-state.sh](../../scripts/bootstrap-terraform-state.sh).
- A master Cloudflare API token (see
  [Master Cloudflare token](#master-cloudflare-token) below).
- A GitHub App created and installed (see [GitHub App](#github-app)
  below).

## Apply

From `terraform/bootstrap/`:

```sh
gcloud auth application-default login
export TF_VAR_billing_account_id=XXXXXX-XXXXXX-XXXXXX
export CLOUDFLARE_API_TOKEN=...   # master, scoped per the section below

terraform init
terraform plan
terraform apply
```

The first apply imports the existing project and three foundational APIs
into bootstrap state, then mints the two scoped Cloudflare API tokens.

After it succeeds, run a one-off apply in `terraform/alunduil/` so its
`removed{}` blocks forget the same four resources from main state
(without destroying them).

## Configure GitHub secrets

```sh
export GH_APP_PRIVATE_KEY="$(cat /path/to/your-app.pem)"
scripts/configure-github-secrets.sh
```

The script reads six values from `terraform output` (four GCP and two
Cloudflare). For the two GitHub App secrets (`GH_APP_ID`,
`GH_APP_PRIVATE_KEY`), it prefers an env-var value, falls back to the
existing repo secret if one is set, and prompts (or in the case of the
PEM, exits with instructions) only when both are missing. Re-running is
a no-op.

## Master Cloudflare token

Bootstrap apply needs a token with the scopes to (a) read permission
groups, (b) create user-owned tokens, and (c) be authorized for
`alunduil.com`:

- `User > API Tokens — Write`
- `Zone > Zone — Read`, `DNS — Read`, `Zone Settings — Read` on
  `alunduil.com` (read is enough; the token only references the zone)

This token is operator-only — it never lives in CI. Mint at
<https://dash.cloudflare.com/profile/api-tokens> for the bootstrap apply,
revoke afterwards if you don't keep it around for rotation.

## GitHub App

The terraform `integrations/github` provider authenticates via a GitHub
App that the workflow exchanges for short-lived installation tokens.
One-time setup:

1. Create at <https://github.com/settings/apps/new>:
   - Webhook: uncheck "Active"
   - Repository permissions: Administration RW, Contents RW, Metadata R
     (auto), Pages RW
2. Install on your account, select "All repositories" so new repos are
   auto-covered.
3. Note the App ID, generate and download a private key (.pem).
4. Export `GH_APP_ID` and `GH_APP_PRIVATE_KEY` (the latter from the .pem
   contents) before running `scripts/configure-github-secrets.sh`.
