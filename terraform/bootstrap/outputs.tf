# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

output "project_id" {
  value       = google_project.env.project_id
  description = "alunduil GCP project ID, consumed by terraform/alunduil/"
  sensitive   = false
}

output "workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Full resource name of the GitHub WIF provider, e.g. projects/<num>/locations/global/workloadIdentityPools/github/providers/github-provider"
  sensitive   = false
}

output "github_deployer_ro_email" {
  value       = google_service_account.github_deployer_ro.email
  description = "Email of the read-only deployer service account (terraform plan)"
  sensitive   = false
}

output "github_deployer_rw_email" {
  value       = google_service_account.github_deployer_rw.email
  description = "Email of the read-write deployer service account (terraform apply)"
  sensitive   = false
}

output "cloudflare_api_token_deployer_ro_secret" {
  value       = google_secret_manager_secret.cloudflare_api_token_deployer_ro.secret_id
  description = "Secret Manager short name holding the RO deployer's Cloudflare API token; fetched at plan time via `gcloud secrets versions access`"
  sensitive   = false
}

output "cloudflare_api_token_deployer_rw_secret" {
  value       = google_secret_manager_secret.cloudflare_api_token_deployer_rw.secret_id
  description = "Secret Manager short name holding the RW deployer's Cloudflare API token; fetched at apply time via `gcloud secrets versions access`"
  sensitive   = false
}

# Grafana Git Sync inputs for terraform/alunduil/. The stack coordinates and App
# identifiers reach the alunduil layer through the published bootstrap-outputs.json
# object (see published_outputs.tf); the two secrets are fetched from Secret
# Manager by the plan and apply workflows.
output "grafana_stack_url" {
  value       = data.grafana_cloud_stack.this.url
  description = "Grafana Cloud stack URL, consumed by terraform/alunduil/"
  sensitive   = false
}

output "grafana_stack_id" {
  value       = data.grafana_cloud_stack.this.id
  description = "Numeric Grafana Cloud stack ID (the stacks-<id> App Platform namespace), consumed by terraform/alunduil/"
  sensitive   = false
}

output "grafana_git_sync_app_id" {
  value       = var.grafana_git_sync_app_id
  description = "Git Sync GitHub App ID, consumed by terraform/alunduil/"
  sensitive   = false
}

output "grafana_git_sync_app_installation_id" {
  value       = var.grafana_git_sync_app_installation_id
  description = "Git Sync GitHub App installation ID on alunduil-infrastructure, consumed by terraform/alunduil/"
  sensitive   = false
}

output "grafana_provisioner_token_secret" {
  value       = google_secret_manager_secret.grafana_provisioner_token.secret_id
  description = "Secret Manager short name holding the Grafana provisioning service-account token; fetched at plan and apply time via `gcloud secrets versions access`"
  sensitive   = false
}

output "grafana_git_sync_app_private_key_secret" {
  value       = google_secret_manager_secret.grafana_git_sync_app_private_key.secret_id
  description = "Secret Manager short name holding the Git Sync GitHub App private key; fetched at plan and apply time via `gcloud secrets versions access`"
  sensitive   = false
}

output "tailscale_oauth_client_id_secret" {
  value       = google_secret_manager_secret.tailscale_oauth_client_id.secret_id
  description = "Secret Manager short name holding the Tailscale OAuth client ID; fetched at plan and apply time via `gcloud secrets versions access`"
  sensitive   = false
}

output "tailscale_oauth_client_secret_secret" {
  value       = google_secret_manager_secret.tailscale_oauth_client_secret.secret_id
  description = "Secret Manager short name holding the Tailscale OAuth client secret; fetched at plan and apply time via `gcloud secrets versions access`"
  sensitive   = false
}
