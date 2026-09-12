<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Tailscale trust credentials

Authenticates the `tailscale` provider from CI without storing a credential.
GitHub Actions mints an OIDC token for the workflow, Tailscale trades it for
an API token good for an hour, and nothing long-lived is kept anywhere. The
tailnet has to be told which workflow to trust, which is a console step.

Make two: plan gets read scopes, apply gets write. Plan runs on pull
requests, and a pull request can edit the workflow that holds the credential
— Renovate edits those files whenever it bumps a pinned action — so the
credential reachable from a branch nobody has reviewed is the one that can't
change anything.

This covers the CI path. Break-glass `just alunduil` runs under your own
identity rather than a workflow's, so it needs its own token — see
[Break-glass](#break-glass).

## Create each credential

Work through the steps below twice, once for each of:

- **Read-only, for plan.** Subject
  `repo:alunduil/alunduil-infrastructure:pull_request`, read access.
- **Read-write, for apply.** Subject
  `repo:alunduil/alunduil-infrastructure:ref:refs/heads/main`, write access.

1. Open the [Trust credentials][trust-credentials] page of the admin console,
   select **Credential**, then select **OpenID Connect**.
2. Select **GitHub** from the **Issuer** dropdown.
3. Replace the prefilled **Subject** with the one listed above.

   The placeholder reads `repo:octo-org/octo-repo:environment:*`, and its
   `environment:` segment matches only jobs that name an environment.
   Neither Terraform workflow does: the plan runs on pull requests and the
   apply on pushes to `main`. Copying the placeholder's shape would leave a
   credential that matches nothing and fails at the first run.
   [OIDC token claims][gh-claims] lists the other forms.
4. Add a custom claim pinning `job_workflow_ref` to
   `alunduil/alunduil-infrastructure/.github/workflows/terraform-plan` for
   the read-only credential, or `.../terraform-apply` for the read-write
   one. The subject alone admits any workflow triggered the same way; this
   narrows each to the one workflow that needs it. Patterns match literally
   except where a `*` stands — see [claim value format][claim-format].
5. Grant that credential's access on each area Terraform touches:

   | Area             | Manages                         |
   | ---------------- | ------------------------------- |
   | Policy File      | tailnet grants                  |
   | DNS              | nameservers, HTTPS certificates |
   | Devices → Core   | device tags, key expiry         |
   | Devices → Routes | subnet routes, exit nodes       |
   | Keys → Auth Keys | auth keys                       |

   Covering all five now keeps the tailnet on these two credentials, so no
   later change has to create a third.
6. Let Tailscale generate the audience. The provider derives it from the
   client ID, so a hand-picked one would have to be carried separately.
7. Copy the **client ID**. There is no secret to capture: the ID is an
   identifier, and presenting it without a matching OIDC token grants
   nothing.

## Store the client IDs

Run `just bootstrap` and paste each ID at its prompt. To answer without the
prompts, set both before the run:

```sh
export TAILSCALE_CLIENT_ID_RO=...
export TAILSCALE_CLIENT_ID_RW=...
```

Each is written once; a later `just bootstrap` finds them populated and asks
for nothing.

## Break-glass

`just alunduil` has no workflow identity to present, so it reads a token from
`TAILSCALE_IDENTITY_TOKEN` and refuses to start without one. It applies, so
it uses the read-write client ID. Supplying the token means a third trust
credential whose issuer is the one that vouches for you locally, created the
same way as above.

[trust-credentials]: https://console.tailscale.com/admin/settings/trust-credentials
[claim-format]: https://tailscale.com/kb/1581/workload-identity-federation#claim-value-format
[gh-claims]: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
