# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

variable "project_id" {
  type        = string
  description = "Google Cloud project holding the pool, the reader, and the secrets."
}

variable "pool" {
  type = object({
    id                   = string
    display_name         = string
    description          = string
    provider_description = string
  })
  description = "The workload identity pool and its GitHub provider."
}

variable "caller" {
  type = object({
    workflow            = string
    ref                 = optional(string)
    principal_attribute = string
  })
  description = <<-EOT
    The one workflow admitted. workflow is owner/repo/.github/workflows/<file>;
    ref null admits any ref. principal_attribute is repository, or
    repository_owner for a reusable workflow that other repositories call.
  EOT

  validation {
    condition     = contains(["repository", "repository_owner"], var.caller.principal_attribute)
    error_message = "principal_attribute must be repository or repository_owner."
  }

  validation {
    condition     = can(regex("^[^/]+/[^/]+/\\.github/workflows/[^/@]+$", var.caller.workflow))
    error_message = "workflow must be owner/repo/.github/workflows/<file>."
  }
}

variable "service_account" {
  type = object({
    account_id   = string
    display_name = string
    description  = string
  })
  description = "The reader service account the workflow federates into."
}

variable "secret_ids" {
  type        = set(string)
  description = "Secret Manager short names the reader may access."
}
