# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

check "default_branch_rename" {
  data "github_repository" "current" {
    name = var.name
  }

  assert {
    condition = data.github_repository.current.default_branch == var.default_branch
    # error_message must reference only plan-time-known values: a newly
    # created repo's data source resolves unknown, and interpolating the live
    # default branch here would fail plan with "Invalid template interpolation
    # value". var.name and var.default_branch are always known.
    error_message = "Repository ${var.name}: the live default branch differs from the configured '${var.default_branch}'. Use GitHub's Rename branch feature (Settings → Branches → Rename) before applying — Terraform won't rename the branch on its own, and only the UI rename preserves PR refs and forks."
  }
}
