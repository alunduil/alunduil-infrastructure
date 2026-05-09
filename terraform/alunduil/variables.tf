# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

variable "billing_account_id" {
  type        = string
  description = "Billing account ID to attach to the project (required for cost allocation)"

  validation {
    condition     = can(regex("^[0-9A-Z]{6}-[0-9A-Z]{6}-[0-9A-Z]{6}$", var.billing_account_id))
    error_message = "Billing account ID must be 18 characters: XXXXXX-XXXXXX-XXXXXX (6 alphanumeric, hyphen, 6 alphanumeric, hyphen, 6 alphanumeric)"
  }
}

# Set explicitly rather than relying on CLOUDFLARE_API_TOKEN: the v5 provider's
# import code path doesn't propagate env-var auth, so import blocks fail with
# "Missing X-Auth-Key, X-Auth-Email or Authorization headers" unless api_token
# is wired through the provider config.
variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token scoped to alunduil.com (Zone:Read + DNS:Edit + Zone Settings:Edit). Export as TF_VAR_cloudflare_api_token."
  sensitive   = true
}

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
      cname          = optional(string)
      build_type     = optional(string, "workflow")
      https_enforced = optional(bool)
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
