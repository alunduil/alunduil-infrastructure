# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

resource "github_repository" "managed" {
  for_each = var.repositories

  name         = each.key
  description  = each.value.description
  homepage_url = each.value.homepage_url
  topics       = each.value.topics

  visibility                  = local.effective_settings[each.key].visibility
  has_issues                  = local.effective_settings[each.key].has_issues
  has_projects                = local.effective_settings[each.key].has_projects
  has_wiki                    = local.effective_settings[each.key].has_wiki
  has_discussions             = local.effective_settings[each.key].has_discussions
  allow_merge_commit          = local.effective_settings[each.key].allow_merge_commit
  allow_squash_merge          = local.effective_settings[each.key].allow_squash_merge
  allow_rebase_merge          = local.effective_settings[each.key].allow_rebase_merge
  allow_auto_merge            = local.effective_settings[each.key].allow_auto_merge
  squash_merge_commit_title   = local.effective_settings[each.key].squash_merge_commit_title
  squash_merge_commit_message = local.effective_settings[each.key].squash_merge_commit_message
  merge_commit_title          = local.effective_settings[each.key].merge_commit_title
  merge_commit_message        = local.effective_settings[each.key].merge_commit_message
  delete_branch_on_merge      = local.effective_settings[each.key].delete_branch_on_merge
  vulnerability_alerts        = local.effective_settings[each.key].vulnerability_alerts
  archive_on_destroy          = local.effective_settings[each.key].archive_on_destroy

  dynamic "pages" {
    for_each = each.value.pages != null ? [each.value.pages] : []
    content {
      cname      = pages.value.cname
      build_type = pages.value.build_type
    }
  }
}

resource "github_branch_default" "managed" {
  for_each = var.repositories

  repository = github_repository.managed[each.key].name
  branch     = each.value.default_branch
}
