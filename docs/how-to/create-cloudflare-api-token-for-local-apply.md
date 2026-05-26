<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Cloudflare API token for local apply

1. Create at <https://dash.cloudflare.com/profile/api-tokens> with the
   following scopes on `alunduil.com`:
   - `Zone:Read`
   - `DNS:Edit`
   - `Zone Settings:Edit`
2. Export as `TF_VAR_cloudflare_api_token` (note the `TF_VAR_` prefix
   — the v5 Cloudflare provider's import code path doesn't propagate
   the bare `CLOUDFLARE_API_TOKEN` env var, so `import {}` blocks
   fail without the explicit variable wiring).
