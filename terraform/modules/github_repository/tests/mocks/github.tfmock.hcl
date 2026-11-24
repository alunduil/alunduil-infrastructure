# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The default_branch_rename check compares against this.
mock_data "github_repository" {
  defaults = { default_branch = "main" }
}
