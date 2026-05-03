# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

locals {
  defaults = {
    visibility                  = "public"
    has_issues                  = true
    has_projects                = false
    has_wiki                    = false
    has_discussions             = false
    allow_merge_commit          = false
    allow_squash_merge          = true
    allow_rebase_merge          = false
    allow_auto_merge            = false
    squash_merge_commit_title   = "PR_TITLE"
    squash_merge_commit_message = "PR_BODY"
    merge_commit_title          = "MERGE_MESSAGE"
    merge_commit_message        = "PR_TITLE"
    delete_branch_on_merge      = true
    vulnerability_alerts        = true
    archive_on_destroy          = true
  }

  classification_overrides = {
    default = {}

    release-please = {
      allow_auto_merge = true
    }
  }

  classification_settings = {
    for name, overrides in local.classification_overrides :
    name => merge(local.defaults, overrides)
  }

  effective_settings = {
    for name, repo in var.repositories : name => {
      visibility                  = repo.visibility != null ? repo.visibility : local.classification_settings[repo.classification].visibility
      has_issues                  = repo.has_issues != null ? repo.has_issues : local.classification_settings[repo.classification].has_issues
      has_projects                = repo.has_projects != null ? repo.has_projects : local.classification_settings[repo.classification].has_projects
      has_wiki                    = repo.has_wiki != null ? repo.has_wiki : local.classification_settings[repo.classification].has_wiki
      has_discussions             = repo.has_discussions != null ? repo.has_discussions : local.classification_settings[repo.classification].has_discussions
      allow_merge_commit          = repo.allow_merge_commit != null ? repo.allow_merge_commit : local.classification_settings[repo.classification].allow_merge_commit
      allow_squash_merge          = repo.allow_squash_merge != null ? repo.allow_squash_merge : local.classification_settings[repo.classification].allow_squash_merge
      allow_rebase_merge          = repo.allow_rebase_merge != null ? repo.allow_rebase_merge : local.classification_settings[repo.classification].allow_rebase_merge
      allow_auto_merge            = repo.allow_auto_merge != null ? repo.allow_auto_merge : local.classification_settings[repo.classification].allow_auto_merge
      squash_merge_commit_title   = repo.squash_merge_commit_title != null ? repo.squash_merge_commit_title : local.classification_settings[repo.classification].squash_merge_commit_title
      squash_merge_commit_message = repo.squash_merge_commit_message != null ? repo.squash_merge_commit_message : local.classification_settings[repo.classification].squash_merge_commit_message
      merge_commit_title          = repo.merge_commit_title != null ? repo.merge_commit_title : local.classification_settings[repo.classification].merge_commit_title
      merge_commit_message        = repo.merge_commit_message != null ? repo.merge_commit_message : local.classification_settings[repo.classification].merge_commit_message
      delete_branch_on_merge      = repo.delete_branch_on_merge != null ? repo.delete_branch_on_merge : local.classification_settings[repo.classification].delete_branch_on_merge
      vulnerability_alerts        = repo.vulnerability_alerts != null ? repo.vulnerability_alerts : local.classification_settings[repo.classification].vulnerability_alerts
      archive_on_destroy          = repo.archive_on_destroy != null ? repo.archive_on_destroy : local.classification_settings[repo.classification].archive_on_destroy
    }
  }
}
