<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Tailscale trust credentials

Authenticates the `tailscale` provider from CI. Creating them and choosing
their scopes are console steps; `just bootstrap` stores the client IDs
afterwards.

Make two: plan gets read scopes, apply gets write, so the credential a pull
request can reach holds no write access.

## Create each credential

On the [Trust credentials][trust-credentials] page choose **Credential**,
then **OpenID Connect**. The form runs **Settings** then **Scopes**; the
values for each credential are below.

Two fields resist copying from what the form offers. The **Subject**
placeholder `repo:octo-org/octo-repo:environment:*` matches only jobs that
name an environment, which neither Terraform workflow does. And the custom
claim carries the ref a run came from, so its trailing `*` is what makes it
match — a pattern without one matches literally, and so matches nothing.

### Read-only, for plan

- **Description** — `alunduil-infrastructure terraform plan`
- **Issuer** — GitHub; the issuer URL fills itself in
- **Subject** — `repo:alunduil/alunduil-infrastructure:pull_request`
- **Custom claim** — key `job_workflow_ref`, value
  `alunduil/alunduil-infrastructure/.github/workflows/terraform-plan.yml@*`

### Read-write, for apply

- **Description** — `alunduil-infrastructure terraform apply`
- **Issuer** — GitHub
- **Subject** — `repo:alunduil/alunduil-infrastructure:ref:refs/heads/main`
- **Custom claim** — key `job_workflow_ref`, value
  `alunduil/alunduil-infrastructure/.github/workflows/terraform-apply.yml@*`

### Scopes

The Scopes page groups every area and offers read or write on each. Leave
the rest untouched:

| Group    | Scope               | Plan | Apply |
| -------- | ------------------- | ---- | ----- |
| General  | DNS                 | Read | Write |
| General  | Policy File         | Read | Write |
| Devices  | Core                | Read | Read  |
| Devices  | Routes              | Read | Write |
| Keys     | Auth Keys           | Read | Read  |
| Settings | Feature Settings    | Read | Write |
| Settings | Networking Settings | Read | Write |

The endpoint behind the tailnet settings answers to several scopes: Feature
Settings covers device approval and key expiry, Networking Settings covers
HTTPS certificates, and Policy File covers the externally-managed flag.

A missing scope reads back as a zero value rather than an error, so a
setting can look imported and still reject the write.

Core and Auth Keys stay at read on both. Write on either demands tags chosen
alongside it, and tags have to exist in the policy file first — which is
itself something Terraform does, through the Policy File scope above. Raise
these two once the tags exist; a trust credential's scopes can be edited
afterwards.

### Finish each one

Leave the audience to Tailscale rather than setting one: the provider
derives it from the client ID, and a hand-picked value would have to be
carried separately. Then copy the **client ID** — there is no secret to
capture.

## Store the client IDs

Run `just bootstrap` and paste each ID at its prompt, or export both
beforehand to skip the prompts:

```sh
export TAILSCALE_CLIENT_ID_RO=...
export TAILSCALE_CLIENT_ID_RW=...
```

## Break-glass

`just alunduil` uses the read-write client ID and needs
`TAILSCALE_IDENTITY_TOKEN` set to a token the tailnet trusts. That means a
third credential, created as above, whose issuer vouches for you locally.

## Stays manual

Terraform manages none of these, so no plan shows them drifting.

Raise a scope in the console before merging the code that needs it. A
rejected write fails the whole apply, not just the resource that asked for
it.

Confirm the partner account holds **Member** rather than Admin on the
[Users][users] page.

Audit the [Keys][keys] page and revoke auth keys that no longer register a
device, reusable ones first.

[keys]: https://console.tailscale.com/admin/settings/keys
[trust-credentials]: https://console.tailscale.com/admin/settings/trust-credentials
[users]: https://console.tailscale.com/admin/users
