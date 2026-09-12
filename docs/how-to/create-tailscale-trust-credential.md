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
- **Scopes** — `policy_file:read`, `dns:read`, `devices:core:read`,
  `devices:routes:read`, `auth_keys:read`

### Read-write, for apply

- **Description** — `alunduil-infrastructure terraform apply`
- **Issuer** — GitHub
- **Subject** — `repo:alunduil/alunduil-infrastructure:ref:refs/heads/main`
- **Custom claim** — key `job_workflow_ref`, value
  `alunduil/alunduil-infrastructure/.github/workflows/terraform-apply.yml@*`
- **Scopes** — `policy_file`, `dns`, `devices:core`, `devices:routes`,
  `auth_keys`

`devices:core` and `auth_keys` require one or more tags chosen alongside
them, so this second credential can't be made before the tags it manages
exist in the policy file.

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

[trust-credentials]: https://console.tailscale.com/admin/settings/trust-credentials
