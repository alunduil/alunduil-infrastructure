<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Grafana Git Sync credentials

The Grafana Cloud inputs for `just bootstrap`; the GitHub side is a
dedicated App in
[create-git-sync-github-app.md](create-git-sync-github-app.md). Do this
first-time and on rotation.

## Stack slug (optional)

`TF_VAR_grafana_stack_slug` — the `<slug>` in
`https://<slug>.grafana.net`. Defaults to `alunduil`, the sole stack
for this infrastructure; only export it to target a different stack.

## Master access-policy token

Used only to read the stack and create the credentials that land in
Secret Manager: the provisioning service-account token and the Fleet
Management access-policy tokens. Create it by hand; recreate when you
next need to run bootstrap.

1. Cloud Portal (<https://grafana.com>, then your org) → **Security →
   Access Policies → Create access policy**. Give it a display name
   (for example, `alunduil-infrastructure-bootstrap`); there is no realm
   field.
2. The **Scopes** grid lists only data-plane resources (metrics, logs,
   …) by default. Select **Add scope** to add the three control-plane
   resources and tick:
    - `stacks` → **read**
    - `stack-service-accounts` → **write**
    - `accesspolicies` → **read**, **write**, **delete**

   `accesspolicies` covers the Fleet Management policies and tokens
   bootstrap creates. `delete` lets a replacement complete rather than
   fail part-applied. Leave every other resource unchecked, then
   **Create**.
3. Select the policy → **Add token** → name it, set a short expiration,
   **Create**, and copy the value — Grafana shows it once.

Export as `TF_VAR_grafana_cloud_access_policy_token`.

## Run

Export it with the other bootstrap inputs (see
[bootstrap.md](bootstrap.md)), then run:

```sh
export TF_VAR_grafana_cloud_access_policy_token=<paste-here>

just bootstrap
```

Revoke the access-policy token once bootstrap finishes.

## Rotate

Regenerate the access-policy token, re-export, and re-run
`just bootstrap`. The next workflow run picks up the new Secret Manager
version. To rotate the GitHub App key, see
[create-git-sync-github-app.md](create-git-sync-github-app.md).

Widening a policy takes a new token as well. Scopes are checked against
the policy, not the token, so a policy created before the scope list
above grew fails mid-apply — but editing it leaves the old token
unable to authenticate, so add the scopes and then create a token.

The two failures read differently, and only one is about scopes:

- `invalid permission: access policy missing required scope [...],
  received [...]` — the policy is too narrow. Add what it names.
- A bare `401 Unauthorized` with no scope list — the token is invalid.
  Create a new one on the policy.
