# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

mock_provider "github" {
  source = "./tests/mocks"
}

variables {
  name                   = "example"
  renovate_commits_check = "Check Renovate branch commits / Hold others' commits on the Renovate branch"
}

run "automerging_repositories_require_the_commit_check" {
  command = plan

  variables {
    required_status_checks = { renovate_automerge = true }
  }

  assert {
    condition = contains([
      for check in github_repository_ruleset.checks.rules[0].required_status_checks[0].required_check :
      check.context
    ], var.renovate_commits_check)
    error_message = "Renovate must not automerge a branch carrying others' commits unreviewed."
  }
}

run "other_repositories_skip_the_commit_check" {
  command = plan

  assert {
    condition = !contains([
      for check in github_repository_ruleset.checks.rules[0].required_status_checks[0].required_check :
      check.context
    ], var.renovate_commits_check)
    error_message = "A repository without Renovate automerge may not run the commit check."
  }
}
