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

## Populate the Inbox sync token

`terraform/bootstrap/` provisions an empty `inbox-sync-token` secret in
Secret Manager. GitHub has no API for minting fine-grained PATs, so the
value lives outside Terraform. Mint the PAT once at
<https://github.com/settings/tokens?type=beta> (resource owner
`alunduil`, repository access "All repositories", permissions: Projects
read+write account-level, Metadata + Issues + Pull requests read on the
three owners' repos), then:

```sh
printf '%s' "<paste-token-here>" |
  gcloud secrets versions add inbox-sync-token \
    --project=alunduil --data-file=-
```

Rotate by repeating the `versions add` call — the workflow always reads
`latest`.
