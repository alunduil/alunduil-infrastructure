<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Tailscale OAuth client

Authenticates the `tailscale` provider. The provider can't create its own
OAuth client, so this is a console step. `just bootstrap` stores both
parts in Secret Manager, where the plan and apply workflows read them.

1. At <https://login.tailscale.com/admin/settings/oauth> choose
   **Generate OAuth client** and give it a description
   (for example `alunduil-infrastructure`).
2. Grant write access on every area Terraform manages. The console
   groups scopes by API area, each with its own read/write toggle:

   | Area             | Access | Manages                         |
   | ---------------- | ------ | ------------------------------- |
   | Policy File      | Write  | the tailnet grants              |
   | DNS              | Write  | nameservers, HTTPS certificates |
   | Devices → Core   | Write  | device tags, key expiry         |
   | Devices → Routes | Write  | subnet routes, exit nodes       |
   | Keys → Auth Keys | Write  | auth keys                       |

   Write access is granted up front so the whole tailnet lands on one
   client, rather than generating a fresh one and rotating the stored
   credential each time a hardening change needs a scope the last
   client lacked.
3. Generate the client and copy both the **client ID** and the **client
   secret**. The secret is shown only at this point — a client whose
   secret wasn't captured has to be replaced rather than read.
4. Run `just bootstrap` and paste each value at its prompt. To answer
   without the prompt, set both before the run:

   ```sh
   export TAILSCALE_OAUTH_CLIENT_ID=...
   export TAILSCALE_OAUTH_CLIENT_SECRET=...
   ```

   Either way the values are written once. A later `just bootstrap`
   finds both secrets populated and asks for nothing.
