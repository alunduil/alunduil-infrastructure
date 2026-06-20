<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the master Cloudflare token

Used once during `terraform/bootstrap/` apply to create the two
deployer Cloudflare tokens. Operator-only — never enters CI.

1. Create at <https://dash.cloudflare.com/profile/api-tokens> with the
   following scopes:
   - `User > API Tokens — Write`
   - `Zone > Zone — Read`, `DNS — Read`, `Zone Settings — Read` on
     `alunduil.com` (read is enough; the token only references the
     zone)
2. Supply it to the bootstrap apply: either `export
   TF_VAR_cloudflare_master_token=...`, or paste it when `just
   bootstrap` prompts for `cloudflare_master_token`.
3. Revoke the token in the Cloudflare dashboard once the apply
   succeeds. Cloudflare only shows the value at creation time, so any
   future bootstrap apply needs a freshly created master token.
