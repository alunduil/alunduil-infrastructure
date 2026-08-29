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
  [create-git-sync-github-app.md](create-git-sync-github-app.md).

## Run

The two master tokens are created by hand and revoked once the apply
finishes, so every run needs a fresh pair.

```sh
gcloud auth application-default login
export TF_VAR_billing_account_id=XXXXXX-XXXXXX-XXXXXX
export CLOUDFLARE_API_TOKEN=...
export TF_VAR_grafana_cloud_access_policy_token=...

just bootstrap
```

`just bootstrap` then prompts for the Git Sync App's ID, installation ID,
and private key, and stores them in Secret Manager. Later runs skip them.
Set `GIT_SYNC_APP_ID`, `GIT_SYNC_APP_INSTALLATION_ID`, and
`GIT_SYNC_APP_PRIVATE_KEY_FILE` to answer without the prompt, or press
Enter at each to defer until the App exists. To replace a stored key, see
[rotate-git-sync-app-key.md](rotate-git-sync-app-key.md).
