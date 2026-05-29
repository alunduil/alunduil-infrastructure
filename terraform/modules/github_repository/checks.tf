# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

check "default_branch_rename" {
  data "github_repository" "current" {
    name = var.name
  }

  assert {
    condition     = data.github_repository.current.default_branch == var.default_branch
    error_message = "Repository ${var.name}: default branch is changing from '${data.github_repository.current.default_branch}' to '${var.default_branch}'. Use GitHub's Rename branch feature (Settings → Branches → Rename) before applying — Terraform won't rename the branch on its own, and only the UI rename preserves PR refs and forks."
  }
}
