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
}

run "uncovered_deployment_tag_fails_plan" {
  command = plan

  variables {
    release_tag_patterns = ["v*"]
    environments         = { pypi = { deployment_tags = ["v*.*.*"] } }
  }

  expect_failures = [var.release_tag_patterns]
}

run "patterns_restrict_tag_creation" {
  command = plan

  variables {
    release_tag_patterns = ["v*.*.*", "woodland-generators-v*"]
    environments         = { pypi = { deployment_tags = ["v*.*.*"] } }
  }

  assert {
    condition = (
      github_repository_ruleset.release_tags[0].conditions[0].ref_name[0].include
      == tolist(["refs/tags/v*.*.*", "refs/tags/woodland-generators-v*"])
    )
    error_message = "The ruleset must cover exactly the given tag patterns."
  }

  assert {
    condition     = github_repository_ruleset.release_tags[0].rules[0].creation
    error_message = "The ruleset must restrict tag creation."
  }
}

run "no_patterns_no_ruleset" {
  command = plan

  assert {
    condition     = length(github_repository_ruleset.release_tags) == 0
    error_message = "A repository without release tag patterns gets no ruleset."
  }
}
