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
- A master Cloudflare API token (see
  [Mint the master Cloudflare token](#mint-the-master-cloudflare-token)
  below).
- A GitHub App created and installed (see
  [Create the GitHub App](#create-the-github-app) below).

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

The first apply imports the existing project and three foundational
APIs into bootstrap state, then mints the two CI deployer Cloudflare
tokens.

After it succeeds, run a one-off `terraform apply` in
`terraform/alunduil/` so its `removed{}` blocks forget the same four
resources from main state without destroying them.

## Configure GitHub Actions secrets

```sh
export GH_APP_PRIVATE_KEY="$(cat /path/to/your-app.pem)"
scripts/configure-github-secrets.sh
```

Re-running is a no-op.

## Mint the master Cloudflare token

Required scopes are in
[reference/credentials.md#master-cloudflare-token](../reference/credentials.md#master-cloudflare-token).

1. Mint at <https://dash.cloudflare.com/profile/api-tokens> with the
   scopes above.
2. Export as `CLOUDFLARE_API_TOKEN` before bootstrap apply.
3. Revoke afterwards if you don't keep it around for rotation.

## Create the GitHub App

Required permissions and install scope are in
[reference/credentials.md#github-app](../reference/credentials.md#github-app).

1. Create at <https://github.com/settings/apps/new> with the
   permissions above. Uncheck the webhook "Active" box.
2. Install on your account with the install scope above.
3. Note the App ID, generate and download a private key (`.pem`).
4. Export `GH_APP_ID` and `GH_APP_PRIVATE_KEY` (the latter from the
   `.pem` contents) before running the secrets script.
