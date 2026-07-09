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

```sh
gcloud auth application-default login
export TF_VAR_billing_account_id=XXXXXX-XXXXXX-XXXXXX
export CLOUDFLARE_API_TOKEN=...
export TF_VAR_grafana_cloud_access_policy_token=...
export TF_VAR_grafana_git_sync_app_id=...
export TF_VAR_grafana_git_sync_app_installation_id=...
export TF_VAR_grafana_git_sync_app_private_key_file=path/to/key.pem

just bootstrap
```
