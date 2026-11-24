# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

mock_provider "github" {
  source = "./tests/mocks"
}

variables {
  name                   = "example"
  required_status_checks = { renovate_automerge = true }
}

run "unprotected_branches_leave_the_rest_protected" {
  command = plan

  variables {
    unprotected_renovate_branches = ["renovate/hook-fix-selftest-*"]
  }

  assert {
    condition = (
      toset(github_repository_ruleset.renovate[0].conditions[0].ref_name[0].exclude)
      == toset(["refs/heads/renovate/hook-fix-selftest-*"])
    )
    error_message = "Each unprotected pattern must be excluded as a full branch ref."
  }

  assert {
    condition = (
      toset(github_repository_ruleset.renovate[0].conditions[0].ref_name[0].include)
      == toset(["refs/heads/renovate/**"])
    )
    error_message = "Every other Renovate branch must stay protected."
  }
}

run "patterns_outside_renovate_are_rejected" {
  command = plan

  variables {
    unprotected_renovate_branches = ["hook-fix-selftest-*"]
  }

  expect_failures = [var.unprotected_renovate_branches]
}
