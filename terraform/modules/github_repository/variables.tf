# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

variable "name" {
  type        = string
  description = "Repository name (the GitHub repository slug)."
}

variable "description" {
  type        = string
  default     = ""
  description = "Short repository description."
}

variable "homepage_url" {
  type        = string
  default     = null
  description = "Optional homepage URL surfaced on the repository page."
}

variable "topics" {
  type        = list(string)
  default     = []
  description = "GitHub topics applied to the repository."
}

variable "default_branch" {
  type        = string
  default     = "main"
  description = <<-EOT
    Branch treated as default and protected. Override only for repos
    predating the main convention. When changing this on an existing
    repo, first use GitHub's "Rename branch" feature
    (Settings → Branches → Rename) so PR refs and forks survive;
    Terraform's github_branch_default only points at an existing
    branch and won't rename anything on its own.
  EOT
}

variable "has_discussions" {
  type        = bool
  default     = false
  description = "Enable GitHub Discussions on the repository."
}

variable "template" {
  type = object({
    owner                = string
    repository           = string
    include_all_branches = optional(bool, false)
  })
  default     = null
  description = "Template repository to seed this one from. Only meaningful at create time."
}

variable "pages" {
  type = object({
    cname          = optional(string)
    build_type     = optional(string, "workflow")
    https_enforced = optional(bool)
  })
  default     = null
  description = <<-EOT
    Enable GitHub Pages with the given CNAME, build_type, and HTTPS
    enforcement. https_enforced can only be set true once GitHub has
    issued the Let's Encrypt cert (auto-provisioned shortly after the
    apex CNAME resolves); for first-time setup, tick "Enforce HTTPS"
    in Settings → Pages once the cert is ready and subsequent applies
    will treat the flag as a no-op confirmation.
  EOT
}
