# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

resource "github_repository" "this" {
  name         = var.name
  description  = var.description
  homepage_url = var.homepage_url
  topics       = var.topics

  visibility                  = "public"
  has_issues                  = true
  has_projects                = false
  has_wiki                    = false
  has_discussions             = var.has_discussions
  allow_merge_commit          = false
  allow_squash_merge          = true
  allow_rebase_merge          = false
  allow_auto_merge            = false
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"
  merge_commit_title          = "MERGE_MESSAGE"
  merge_commit_message        = "PR_TITLE"
  delete_branch_on_merge      = true
  archive_on_destroy          = true

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }

  dynamic "template" {
    for_each = var.template != null ? [var.template] : []
    content {
      owner                = template.value.owner
      repository           = template.value.repository
      include_all_branches = template.value.include_all_branches
    }
  }
}

resource "github_branch_default" "this" {
  repository = github_repository.this.name
  branch     = var.default_branch
}

# Default-branch protection. Ruleset (not classic github_branch_protection)
# because rulesets are GitHub's strategic mechanism and the only one with
# first-class bypass actors — needed here since a solo maintainer can't satisfy
# a required-review count. The repository admin bypasses with mode "always" so
# direct pushes to the default branch remain possible when wanted, while the
# default path stays PR-with-resolved-conversations.
resource "github_repository_ruleset" "default_branch" {
  name        = "default"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  depends_on = [github_branch_default.this]

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  bypass_actors {
    actor_id    = 5 # built-in repository "admin" role
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true

    pull_request {
      required_approving_review_count   = 0
      required_review_thread_resolution = true
    }
  }
}

resource "github_repository_vulnerability_alerts" "this" {
  repository = github_repository.this.name
}

resource "github_repository_pages" "this" {
  count = var.pages != null ? 1 : 0

  repository     = github_repository.this.name
  build_type     = var.pages.build_type
  cname          = var.pages.cname
  https_enforced = var.pages.https_enforced

  # source is only valid for build_type = "legacy"; the GitHub API rejects it
  # for workflow builds.
  dynamic "source" {
    for_each = var.pages.build_type == "legacy" ? [1] : []
    content {
      branch = var.default_branch
    }
  }
}
