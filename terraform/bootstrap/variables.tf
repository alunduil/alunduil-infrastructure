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
  description = "Master Cloudflare token: User > API Tokens — Write plus Zone/DNS/Zone-Settings Read on alunduil.com. Create at https://dash.cloudflare.com/profile/api-tokens and revoke after apply. Full steps: docs/how-to/create-master-cloudflare-token.md"
}
