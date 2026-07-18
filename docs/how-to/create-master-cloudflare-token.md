<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the master Cloudflare token

Used once during `terraform/bootstrap/` apply to create the two
deployer Cloudflare tokens. Operator-only — never enters CI.

1. At <https://dash.cloudflare.com/profile/api-tokens> choose
   **Create Token** → **Create Custom Token**. Under **Permissions**
   each row has three dropdowns — the group (defaults to `Account`),
   the permission, and the access level. Add these rows:

   | Group | Permission    | Access |
   | ----- | ------------- | ------ |
   | User  | API Tokens    | Edit   |
   | Zone  | Zone          | Read   |
   | Zone  | DNS           | Read   |
   | Zone  | Zone Settings | Read   |

   Under **Zone Resources** set `Include` → `Specific zone` →
   `alunduil.com` (read is enough; the token only references the zone).

   Under **TTL** set an **Expiration Date** a day or two out. The token
   self-revokes when it lapses, so a bootstrap run can't leave a
   standing `User > API Tokens` credential behind.
2. Supply it to the bootstrap apply by exporting it before running
   `just bootstrap`:

   ```sh
   export TF_VAR_cloudflare_master_token=...
   ```

   Exporting sidesteps Terraform's interactive prompt, which can mangle
   tokens pasted into terminals with bracketed paste enabled. The
   prompt still works as a fallback if you skip the export.
3. Once the apply succeeds you can revoke the token in the dashboard
   early, but the expiration handles it if you don't. Cloudflare only
   shows the value at creation time, so any future bootstrap apply
   needs a freshly created master token.
