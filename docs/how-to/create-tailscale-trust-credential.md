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
2. Set the issuer to `https://token.actions.githubusercontent.com`, GitHub's
   OIDC issuer.
3. Match the subject to this repository's workflows. GitHub's subject format
   is documented under [OIDC token claims][gh-claims]; scope it to
   `alunduil/alunduil-infrastructure` rather than leaving a pattern that any
   repository on the account would satisfy.
4. Grant the scopes Terraform needs. The console lists read and write per
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
5. Let Tailscale generate the audience. The provider derives it from the
   client ID, so a hand-picked one would have to be carried separately.
6. Copy the **client ID**. There is no secret to capture: the ID is an
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
[gh-claims]: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
