# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

variable "repositories" {
  description = "Map of GitHub repositories to manage, keyed by repository name"
  type = map(object({
    description                 = optional(string, "")
    classification              = optional(string, "default")
    homepage_url                = optional(string)
    topics                      = optional(list(string), [])
    visibility                  = optional(string)
    has_issues                  = optional(bool)
    has_projects                = optional(bool)
    has_wiki                    = optional(bool)
    has_discussions             = optional(bool)
    allow_merge_commit          = optional(bool)
    allow_squash_merge          = optional(bool)
    allow_rebase_merge          = optional(bool)
    allow_auto_merge            = optional(bool)
    squash_merge_commit_title   = optional(string)
    squash_merge_commit_message = optional(string)
    merge_commit_title          = optional(string)
    merge_commit_message        = optional(string)
    delete_branch_on_merge      = optional(bool)
    vulnerability_alerts        = optional(bool)
    archive_on_destroy          = optional(bool)
    default_branch              = optional(string)
    template = optional(object({
      owner                = string
      repository           = string
      include_all_branches = optional(bool, false)
    }))
    pages = optional(object({
      cname      = optional(string)
      build_type = optional(string, "workflow")
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, repo in var.repositories :
      contains(["default", "release-please"], repo.classification)
    ])
    error_message = "Classification must be one of: default, release-please."
  }
}
