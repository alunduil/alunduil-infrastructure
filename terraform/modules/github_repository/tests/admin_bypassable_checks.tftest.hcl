# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

mock_provider "github" {
  # The default_branch_rename check compares against this.
  mock_data "github_repository" {
    defaults = { default_branch = "main" }
  }
}

variables {
  name = "example"
  required_status_checks = {
    contexts                  = ["Build"]
    admin_bypassable_contexts = ["Confirm"]
    renovate_automerge        = true
  }
}

run "only_the_admin_bypasses_only_the_bypassable_checks" {
  command = plan

  assert {
    condition = [
      for actor in github_repository_ruleset.admin_bypassable_checks[0].bypass_actors :
      "${actor.actor_type}:${actor.actor_id}:${actor.bypass_mode}"
    ] == ["RepositoryRole:5:pull_request"]
    error_message = "The admin role, through a pull request, must be the only bypass."
  }

  assert {
    condition = [
      for check in github_repository_ruleset.admin_bypassable_checks[0].rules[0].required_status_checks[0].required_check :
      check.context
    ] == ["Confirm"]
    error_message = "The bypass must reach the bypassable contexts alone."
  }

  assert {
    condition = (
      length(github_repository_ruleset.checks.bypass_actors) == 0
      && !contains([
        for check in github_repository_ruleset.checks.rules[0].required_status_checks[0].required_check :
        check.context
      ], "Confirm")
    )
    error_message = "The checks ruleset must keep no bypass and leave out the bypassable contexts."
  }
}

run "admin_only_repositories_are_rejected" {
  command = plan

  variables {
    admin_only_updates = true
  }

  expect_failures = [github_repository_ruleset.admin_bypassable_checks]
}
