<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Items outside Terraform

Things that sit outside the Terraform configs, either because the
provider doesn't expose them cleanly or because they're one-time
bootstraps.

- **Default-branch rename** — Terraform can't safely rename an
  existing default branch without losing PR refs and forks. See
  [how-to/rename-default-branch.md](../how-to/rename-default-branch.md).
- **HTTPS enforcement on GitHub Pages** — the certificate is
  provisioned automatically once the CNAME resolves, and the
  "Enforce HTTPS" toggle is set after the fact. See
  [how-to/enable-https-on-pages.md](../how-to/enable-https-on-pages.md).
