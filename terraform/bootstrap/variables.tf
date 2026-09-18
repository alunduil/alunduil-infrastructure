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

# Account Analytics is here for the blog's account-scoped analytics token; the
# rest of the rows serve the two zone-scoped deployer tokens.
variable "cloudflare_master_token" {
  type        = string
  sensitive   = true
  description = <<-EOT
    Master Cloudflare token, created by hand and revoked after apply.

    At https://dash.cloudflare.com/profile/api-tokens choose
    Create Custom Token. Each Permissions row has three dropdowns —
    group (defaults to Account), permission, access. Add these rows:

      User    | API Tokens        | Edit
      Zone    | Zone              | Read
      Zone    | DNS               | Read
      Zone    | Zone Settings     | Read
      Account | Account Analytics | Read

    Set Zone Resources to: Include | Specific zone | alunduil.com, and
    Account Resources to: Include | alunduil-infrastructure.

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

    At https://grafana.com choose your org, then
    Security > Access Policies. On the alunduil-infrastructure-bootstrap
    policy choose Add token, set a short expiration, and copy the value
    (shown once).

    Full steps: docs/how-to/create-grafana-git-sync-token.md
  EOT
}
