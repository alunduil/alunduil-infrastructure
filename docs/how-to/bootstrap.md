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
- Grafana Git Sync credentials — see
  [create-grafana-git-sync-token.md](create-grafana-git-sync-token.md).

## Run

```sh
gcloud auth application-default login
export TF_VAR_billing_account_id=XXXXXX-XXXXXX-XXXXXX
export CLOUDFLARE_API_TOKEN=...
export TF_VAR_grafana_stack_slug=...
export TF_VAR_grafana_cloud_access_policy_token=...
export TF_VAR_grafana_git_sync_github_token=...

just bootstrap
```
