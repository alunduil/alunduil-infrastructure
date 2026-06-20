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
