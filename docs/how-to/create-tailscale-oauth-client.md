<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Tailscale OAuth client

Authenticates the `tailscale` provider. The provider can't create its
own OAuth client, so this is a console step. Supplied once during
`terraform/bootstrap/` apply, which stores both parts in Secret Manager
for the plan and apply workflows to read.

1. At <https://login.tailscale.com/admin/settings/oauth> choose
   **Generate OAuth client**. Give it a description
   (e.g. `alunduil-infrastructure`) and grant the scope the scaffold
   needs:

   | Scope          | Access |
   | -------------- | ------ |
   | Devices → Core | Read   |

   That is the `devices:core:read` scope — enough for the provider to
   authenticate and read the device list. Managing the tailnet (ACL,
   DNS, tags, auth keys, routes) needs write scopes the scaffold does
   not; the import and hardening work grants those on a fresh client,
   since a client's scopes are fixed at creation.
2. Generate the client and copy both the **client ID** and the
   **client secret**. The secret is shown only at creation time.
3. Supply them to the bootstrap apply by exporting them before running
   `just bootstrap`:

   ```sh
   export TF_VAR_tailscale_oauth_client_id=...
   export TF_VAR_tailscale_oauth_client_secret=...
   ```

   Exporting sidesteps Terraform's interactive prompt, which can mangle
   values pasted into terminals with bracketed paste enabled.
