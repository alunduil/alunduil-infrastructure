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
- The deployer GitHub App created and installed — see
  [create-deployer-github-app.md](create-deployer-github-app.md).
- Grafana Cloud credentials — see
  [create-grafana-git-sync-token.md](create-grafana-git-sync-token.md).
- A Git Sync GitHub App created and installed — see
  [create-git-sync-github-app.md](create-git-sync-github-app.md). Press
  Enter past its prompts to defer it; a later run picks the values up.

## Run

Every run needs all three values below. The two master tokens are created
by hand and revoked once the apply finishes, so they're new each time.

```sh
gcloud auth application-default login
export TF_VAR_billing_account_id=XXXXXX-XXXXXX-XXXXXX
export CLOUDFLARE_API_TOKEN=...
export TF_VAR_grafana_cloud_access_policy_token=...

just bootstrap
```

The Git Sync App's ID, installation ID, and private key are asked for at
a prompt, stored in Secret Manager, and skipped on every later run. Set
`GIT_SYNC_APP_ID`, `GIT_SYNC_APP_INSTALLATION_ID`, and
`GIT_SYNC_APP_PRIVATE_KEY_FILE` to answer without the prompt. Replacing a
stored key is [rotate-git-sync-app-key.md](rotate-git-sync-app-key.md),
not a re-run.
