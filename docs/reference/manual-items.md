<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Items outside Terraform

Things that sit outside the Terraform configs, either because the
provider doesn't expose them cleanly or because they're one-time
bootstraps.

- **`develop` → `main` default-branch rename** — Terraform can't safely
  rename an existing default branch without losing PR refs and forks.
- **HTTPS enforcement on GitHub Pages** — the certificate is provisioned
  automatically once the CNAME resolves, and the "Enforce HTTPS"
  toggle is set after the fact.
- **Cloudflare API token for local apply** — see
  [credentials.md](credentials.md#cloudflare-api-token-alunduil-apply)
  for required scopes.

Procedures for each item are in
[how-to/manual-operations.md](../how-to/manual-operations.md).
