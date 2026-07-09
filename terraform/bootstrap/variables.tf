# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

variable "billing_account_id" {
  type        = string
  description = "Billing account ID to attach to the alunduil project. Lives in bootstrap so CI never needs billing perms."

  validation {
    condition     = can(regex("^[0-9A-Z]{6}-[0-9A-Z]{6}-[0-9A-Z]{6}$", var.billing_account_id))
    error_message = "Billing account ID must be 18 characters: XXXXXX-XXXXXX-XXXXXX (6 alphanumeric, hyphen, 6 alphanumeric, hyphen, 6 alphanumeric)"
  }
}

variable "cloudflare_master_token" {
  type        = string
  sensitive   = true
  description = <<-EOT
    Master Cloudflare token, created by hand and revoked after apply.

    At https://dash.cloudflare.com/profile/api-tokens choose
    Create Custom Token. Each Permissions row has three dropdowns —
    group (defaults to Account), permission, access. Add these rows:

      User | API Tokens    | Edit
      Zone | Zone          | Read
      Zone | DNS           | Read
      Zone | Zone Settings | Read

    Set Zone Resources to: Include | Specific zone | alunduil.com.

    Full steps: docs/how-to/create-master-cloudflare-token.md
  EOT
}

variable "grafana_stack_slug" {
  type        = string
  default     = "alunduil"
  description = "Grafana Cloud stack slug (the <slug> in https://<slug>.grafana.net). Defaults to the sole stack for this personal infrastructure; override only for a different stack. Not a secret."
}

variable "grafana_cloud_access_policy_token" {
  type        = string
  sensitive   = true
  description = <<-EOT
    Master Grafana Cloud access-policy token, created by hand and revoked
    after apply. Used only to read the stack and create the provisioning
    service-account token stored in Secret Manager.

    In the Cloud Portal (grafana.com, then your org) go to
    Security > Access Policies > Create access policy. The Scopes grid
    lists only data-plane resources by default; click Add scope to add:

      stacks                 read
      stack-service-accounts write

    Save, then Add token on the policy and copy the value (shown once).

    Full steps: docs/how-to/create-grafana-git-sync-token.md
  EOT
}

variable "grafana_git_sync_app_id" {
  type        = string
  description = "App ID of the dedicated Git Sync GitHub App. Not a secret; output for the alunduil layer's Grafana connection resource."
}

variable "grafana_git_sync_app_installation_id" {
  type        = string
  description = "Installation ID of the Git Sync GitHub App on alunduil-infrastructure. Not a secret; output for the alunduil layer."
}

variable "grafana_git_sync_app_private_key" {
  type        = string
  sensitive   = true
  description = <<-EOT
    PEM private key of the dedicated Git Sync GitHub App, installed only on
    alunduil-infrastructure with Contents and Pull requests: write. Grafana
    uses it to mint installation tokens. Hand-created (GitHub has no API to
    create Apps or their keys), then stored in Secret Manager here.

    Full steps: docs/how-to/create-grafana-git-sync-app.md
  EOT
}
