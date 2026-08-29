# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Set explicitly rather than relying on CLOUDFLARE_API_TOKEN: the v5 provider's
# import code path doesn't propagate env-var auth, so import blocks fail with
# "Missing X-Auth-Key, X-Auth-Email or Authorization headers" unless api_token
# is wired through the provider config.
variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token scoped to alunduil.com (Zone:Read + DNS:Edit + Zone Settings:Edit). Export as TF_VAR_cloudflare_api_token."
  sensitive   = true
}

# Every Grafana value below is stored in Secret Manager by the bootstrap layer
# and exported as TF_VAR_grafana_* by the plan/apply workflows, exactly like
# cloudflare_api_token. The stack URL and ID are non-secret and come from the
# bootstrap remote state, so they are not variables here.
variable "grafana_service_account_token" {
  type        = string
  description = "Grafana stack service-account token authenticating the provider to the App Platform API. Export as TF_VAR_grafana_service_account_token."
  sensitive   = true
}

variable "grafana_git_sync_app_private_key" {
  type        = string
  description = "PEM private key of the dedicated Git Sync GitHub App; Grafana uses it to generate installation tokens for alunduil-infrastructure. Export as TF_VAR_grafana_git_sync_app_private_key."
  sensitive   = true
}

# The two identifiers below are not secret. They share the private key's store
# because none of the three exists until the App is registered by hand, which
# leaves the bootstrap layer nothing to publish alongside the stack coordinates.
variable "grafana_git_sync_app_id" {
  type        = string
  description = "App ID of the dedicated Git Sync GitHub App. Export as TF_VAR_grafana_git_sync_app_id."
}

variable "grafana_git_sync_app_installation_id" {
  type        = string
  description = "Installation ID of the Git Sync GitHub App on alunduil-infrastructure. Export as TF_VAR_grafana_git_sync_app_installation_id."
}
