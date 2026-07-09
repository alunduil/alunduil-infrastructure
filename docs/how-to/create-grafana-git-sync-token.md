<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Grafana Git Sync credentials

The bootstrap layer reads the Grafana Cloud stack and derives the
credentials that let `terraform/alunduil` provision dashboards through
Git Sync. It needs three inputs, mirroring the Cloudflare master token:
a stack slug, a master access-policy token (revoked after apply), and a
GitHub PAT. Follow this before `just bootstrap`, both first-time and on
rotation.

## Stack slug

`TF_VAR_grafana_stack_slug` — the `<slug>` in
`https://<slug>.grafana.net`. Not a secret. The bootstrap layer reads
the stack by this slug and outputs its URL and numeric ID for the
alunduil layer.

## Master access-policy token

Used only to read the stack and create the provisioning service-account
token that lands in Secret Manager. Create it by hand and revoke it once
`just bootstrap` finishes; recreate when you next need to run bootstrap.

1. Grafana Cloud portal → **Security → Access Policies → Create access
   policy**.
2. Scopes: **`stacks:read`** and **`stack-service-accounts:write`**.
3. Create a token under the policy and copy the value.

Export as `TF_VAR_grafana_cloud_access_policy_token`.

## GitHub PAT for Git Sync

Git Sync reads the repo and opens pull requests for dashboards edited in
the UI (the repository uses the `branch` workflow because the
default-branch ruleset blocks direct pushes to `main`). A fine-grained
PAT scoped to just this repo is the tightest grant; GitHub has no API to
mint it, so it is hand-created and then stored in Secret Manager by
bootstrap.

1. Open <https://github.com/settings/personal-access-tokens/new>.
2. **Resource owner**: `alunduil`. **Repository access**: only
   `alunduil-infrastructure`.
3. **Repository permissions**:
    - **Contents**: Read and write — read dashboards, push the branch.
    - **Pull requests**: Read and write — open the sync PR.
4. Generate and copy the value.

Export as `TF_VAR_grafana_git_sync_github_token`.

## Run

Export all three alongside the other bootstrap inputs and run
`just bootstrap` (see [bootstrap.md](bootstrap.md)):

```sh
export TF_VAR_grafana_stack_slug=<slug>
export TF_VAR_grafana_cloud_access_policy_token=<paste-here>
export TF_VAR_grafana_git_sync_github_token=<paste-here>

just bootstrap
```

Bootstrap creates a Grafana provisioning service account, stores its
token and the GitHub PAT in Secret Manager, and grants the plan/apply
deployer service accounts access. The `terraform-plan` and
`terraform-apply` workflows fetch both at run time; the stack URL and ID
reach the alunduil layer through the bootstrap remote state. Revoke the
access-policy token afterward.

## Rotate

Regenerate whichever credential changed, re-export, and re-run
`just bootstrap`. The next workflow run picks up the new Secret Manager
version.
