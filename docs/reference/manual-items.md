<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Items outside Terraform

Things that sit outside the Terraform configs, either because the
provider doesn't expose them cleanly or because they're one-time
bootstraps.

- **Default-branch rename** — Terraform can't safely rename an
  existing default branch without losing PR refs and forks. See
  [how-to/rename-default-branch.md](../how-to/rename-default-branch.md).
