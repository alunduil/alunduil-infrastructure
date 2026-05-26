<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Rename the default branch

1. In the repo's GitHub settings, use "Rename branch" under "Default
   branch" to rename the old default to the new one. GitHub preserves
   PR refs and forks across the rename.
2. Let the next Terraform apply pick up `github_branch_default` for
   the new name.
