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

resource "github_branch_protection" "this" {
  repository_id = github_repository.this.node_id
  pattern       = github_branch_default.this.branch

  allows_deletions    = false
  allows_force_pushes = false

  dynamic "required_status_checks" {
    for_each = var.required_status_checks != null ? [var.required_status_checks] : []
    content {
      strict   = required_status_checks.value.strict
      contexts = required_status_checks.value.contexts
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
