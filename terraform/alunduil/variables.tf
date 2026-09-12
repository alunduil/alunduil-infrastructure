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
# cloudflare_api_token. The stack URL and ID come from bootstrap-outputs.json,
# so they are not variables here.
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

# The two identifiers below are not secret. They arrive by the same route as the
# key because none of the three exists until the App is registered by hand.
variable "grafana_git_sync_app_id" {
  type        = string
  description = "App ID of the dedicated Git Sync GitHub App. Export as TF_VAR_grafana_git_sync_app_id."
}

variable "grafana_git_sync_app_installation_id" {
  type        = string
  description = "Installation ID of the Git Sync GitHub App on alunduil-infrastructure. Export as TF_VAR_grafana_git_sync_app_installation_id."
}

# Left unmarked: a caller holding the id still needs an OIDC token matching the
# credential's issuer, subject, and audience rules.
variable "tailscale_client_id" {
  type        = string
  description = "Client ID of the Tailscale trust credential the provider federates against. Export as TF_VAR_tailscale_client_id."
}

# Empty on a runner, which mints its own. Sensitive despite expiring within the
# hour: it is a bearer token until it does.
variable "tailscale_identity_token" {
  type        = string
  default     = ""
  description = "OIDC token the Tailscale trust credential accepts, for runs outside a federated runtime. Export as TF_VAR_tailscale_identity_token."
  sensitive   = true
}
