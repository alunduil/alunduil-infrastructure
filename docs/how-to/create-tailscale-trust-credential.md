<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Tailscale trust credential

Authenticates the `tailscale` provider from CI without storing a credential.
GitHub Actions mints an OIDC token for the workflow, Tailscale trades it for
an API token good for an hour, and nothing long-lived is kept anywhere. The
tailnet has to be told which workflow to trust, which is a console step.

This covers the CI path. Break-glass `just alunduil` runs under your own
identity rather than a workflow's, so it needs its own token — see
[Break-glass](#break-glass).

## Create the credential

1. Open the [Trust credentials][trust-credentials] page of the admin console,
   select **Credential**, then select **OpenID Connect**.
2. Select **GitHub** from the **Issuer** dropdown.
3. Replace the prefilled **Subject** with
   `repo:alunduil/alunduil-infrastructure:*`.

   The placeholder reads `repo:octo-org/octo-repo:environment:*`, and its
   `environment:` segment matches only jobs that name an environment.
   Neither Terraform workflow does: the plan runs on pull requests and the
   apply on pushes to `main`, so their subjects end `:pull_request` and
   `:ref:refs/heads/main`. Copying the placeholder's shape would leave a
   credential that matches nothing and fails at the first plan. The trailing
   `*` covers both. [OIDC token claims][gh-claims] lists the other forms.
4. Add a custom claim pinning `job_workflow_ref` to
   `alunduil/alunduil-infrastructure/.github/workflows/terraform-*`. The
   subject above admits any workflow in the repository; this narrows it to
   the two that manage the tailnet. Patterns match literally except where a
   `*` stands — see [claim value format][claim-format].
5. Grant the scopes Terraform needs. The console lists read and write per
   API area:

   | Area             | Access | Manages                         |
   | ---------------- | ------ | ------------------------------- |
   | Policy File      | Write  | tailnet grants                  |
   | DNS              | Write  | nameservers, HTTPS certificates |
   | Devices → Core   | Write  | device tags, key expiry         |
   | Devices → Routes | Write  | subnet routes, exit nodes       |
   | Keys → Auth Keys | Write  | auth keys                       |

   Granting all five now keeps the tailnet on one credential, so no later
   change has to create a second one.
6. Let Tailscale generate the audience. The provider derives it from the
   client ID, so a hand-picked one would have to be carried separately.
7. Copy the **client ID**. There is no secret to capture: the ID is an
   identifier, and presenting it without a matching OIDC token grants
   nothing.

## Store the client ID

Run `just bootstrap` and paste the ID at its prompt. To answer without the
prompt, set it before the run:

```sh
export TAILSCALE_CLIENT_ID=...
```

It's written once; a later `just bootstrap` finds it populated and asks for
nothing.

## Break-glass

`just alunduil` has no workflow identity to present, so it reads a token from
`TAILSCALE_IDENTITY_TOKEN` and refuses to start without one. Supplying it
means a second trust credential whose issuer is the one that vouches for you
locally, created the same way as above.

[trust-credentials]: https://console.tailscale.com/admin/settings/trust-credentials
[claim-format]: https://tailscale.com/kb/1581/workload-identity-federation#claim-value-format
[gh-claims]: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
