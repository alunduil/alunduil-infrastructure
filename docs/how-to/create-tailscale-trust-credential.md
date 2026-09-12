<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Tailscale trust credentials

Authenticates the `tailscale` provider from CI. Creating them and choosing
their scopes are console steps; `just bootstrap` stores the client IDs
afterwards.

## Create each credential

Make two, so the credential a pull request can reach holds no write access.
Work through the steps below once for each:

- **Read-only, for plan.** Subject
  `repo:alunduil/alunduil-infrastructure:pull_request`, read access.
- **Read-write, for apply.** Subject
  `repo:alunduil/alunduil-infrastructure:ref:refs/heads/main`, write access.

1. Open the [Trust credentials][trust-credentials] page of the admin console,
   select **Credential**, then select **OpenID Connect**.
2. Select **GitHub** from the **Issuer** dropdown.
3. Replace the prefilled **Subject** with the one listed above. The
   placeholder's `environment:` segment matches only jobs that name an
   environment, which neither Terraform workflow does — copy its shape and
   the credential matches nothing. [OIDC token claims][gh-claims] lists the
   forms.
4. Add a custom claim pinning `job_workflow_ref` to
   `alunduil/alunduil-infrastructure/.github/workflows/terraform-plan` for
   the read-only credential, `.../terraform-apply` for the read-write one.
   Patterns match literally except where a `*` stands — see
   [claim value format][claim-format].
5. Grant that credential's access on each area Terraform touches:

   | Area             | Manages                         |
   | ---------------- | ------------------------------- |
   | Policy File      | tailnet grants                  |
   | DNS              | nameservers, HTTPS certificates |
   | Devices → Core   | device tags, key expiry         |
   | Devices → Routes | subnet routes, exit nodes       |
   | Keys → Auth Keys | auth keys                       |

6. Let Tailscale generate the audience. The provider derives it from the
   client ID, so a hand-picked one would have to be carried separately.
7. Copy the **client ID**. There is no secret to capture.

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
[claim-format]: https://tailscale.com/kb/1581/workload-identity-federation#claim-value-format
[gh-claims]: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
