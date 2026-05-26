<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Manual operations

Procedures for the items in
[reference/manual-items.md](../reference/manual-items.md).

## Create the Cloudflare API token for local apply

1. Create at <https://dash.cloudflare.com/profile/api-tokens> with the
   following scopes on `alunduil.com`:
   - `Zone:Read`
   - `DNS:Edit`
   - `Zone Settings:Edit`
2. Export as `TF_VAR_cloudflare_api_token` (note the `TF_VAR_` prefix
   — the v5 Cloudflare provider's import code path doesn't propagate
   the bare `CLOUDFLARE_API_TOKEN` env var, so `import {}` blocks
   fail without the explicit variable wiring).

## Rename default branch from `develop` to `main`

1. In the repo's GitHub settings, use "Rename branch" under "Default
   branch" to rename `develop` → `main`. GitHub preserves PR refs and
   forks across the rename.
2. Let the next Terraform apply pick up `github_branch_default` for
   `main`.

## Enable HTTPS on a GitHub Pages site

GitHub provisions the certificate on its own once the apex CNAME
resolves; the toggle is set after that.

1. Wait for the CNAME to resolve and GitHub to provision a Let's
   Encrypt cert (usually minutes after the DNS record lands).
2. In the repo's "Settings → Pages", tick "Enforce HTTPS".

Once the cert is ready, `https_enforced = true` on the
`github_repository_pages` resource keeps the toggle locked in.
