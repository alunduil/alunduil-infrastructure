# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

mock_provider "github" {
  source = "./tests/mocks"
}

variables {
  name = "example"
}

run "patterns_restrict_tag_creation" {
  command = plan

  variables {
    release_tag_patterns = ["v*.*.*", "woodland-generators-v*"]
    environments = {
      pypi    = { deployment_tags = ["v*.*.*"] }
      release = { deployment_tags = ["foundry-module@*"] }
    }
  }

  assert {
    condition = (
      toset(github_repository_ruleset.release_tags[0].conditions[0].ref_name[0].include)
      == toset(["refs/tags/v*.*.*", "refs/tags/foundry-module@*", "refs/tags/woodland-generators-v*"])
    )
    error_message = "The ruleset must cover every environment's deployment_tags and release_tag_patterns."
  }

  assert {
    condition     = length(github_repository_ruleset.release_tags[0].conditions[0].ref_name[0].include) == 3
    error_message = "A pattern listed twice must appear once."
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
