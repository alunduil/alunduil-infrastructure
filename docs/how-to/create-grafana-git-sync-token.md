<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Grafana Git Sync credentials

The bootstrap layer reads the Grafana Cloud stack and derives the
credentials that let `terraform/alunduil` provision dashboards through
Git Sync. This covers the Grafana Cloud inputs; the GitHub side is a
dedicated App in
[create-grafana-git-sync-app.md](create-grafana-git-sync-app.md).
Follow this before `just bootstrap`, both first-time and on rotation.

## Stack slug (optional)

`TF_VAR_grafana_stack_slug` — the `<slug>` in
`https://<slug>.grafana.net`. Defaults to `alunduil`, the sole stack
for this infrastructure; only export it to target a different stack.
The bootstrap layer reads the stack by this slug and outputs its URL
and numeric ID for the alunduil layer.

## Master access-policy token

Used only to read the stack and create the provisioning service-account
token that lands in Secret Manager. Create it by hand and revoke it once
`just bootstrap` finishes; recreate when you next need to run bootstrap.

1. Grafana Cloud portal → **Security → Access Policies → Create access
   policy**.
2. Scopes: **`stacks:read`** and **`stack-service-accounts:write`**.
3. Create a token under the policy and copy the value.

Export as `TF_VAR_grafana_cloud_access_policy_token`.

## Run

Export it alongside the Git Sync App inputs and the other bootstrap
inputs, then run `just bootstrap` (see [bootstrap.md](bootstrap.md)):

```sh
export TF_VAR_grafana_cloud_access_policy_token=<paste-here>

just bootstrap
```

Bootstrap creates a Grafana provisioning service account, stores its
token and the Git Sync App private key in Secret Manager, and grants the
plan/apply deployer service accounts access. The `terraform-plan` and
`terraform-apply` workflows fetch both at run time; the stack URL and ID
reach the alunduil layer through the bootstrap remote state. Revoke the
access-policy token afterward.

## Rotate

Regenerate the access-policy token, re-export, and re-run
`just bootstrap`. The next workflow run picks up the new Secret Manager
version. To rotate the GitHub App key, see
[create-grafana-git-sync-app.md](create-grafana-git-sync-app.md).
