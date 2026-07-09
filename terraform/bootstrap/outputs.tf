# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

output "project_id" {
  value       = google_project.env.project_id
  description = "alunduil GCP project ID, consumed by terraform/alunduil/ via terraform_remote_state"
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

output "grafana_stack_url" {
  value       = data.grafana_cloud_stack.this.url
  description = "Grafana Cloud stack URL, consumed by terraform/alunduil/ via terraform_remote_state to configure the App Platform provider"
  sensitive   = false
}

output "grafana_stack_id" {
  value       = data.grafana_cloud_stack.this.id
  description = "Numeric Grafana Cloud stack ID; selects the stacks-<id> App Platform namespace in terraform/alunduil/"
  sensitive   = false
}

output "grafana_provisioner_token_secret" {
  value       = google_secret_manager_secret.grafana_provisioner_token.secret_id
  description = "Secret Manager short name holding the Grafana provisioning service-account token; fetched by both plan and apply via `gcloud secrets versions access`"
  sensitive   = false
}

output "grafana_git_sync_github_token_secret" {
  value       = google_secret_manager_secret.grafana_git_sync_github_token.secret_id
  description = "Secret Manager short name holding the Git Sync GitHub PAT; fetched by both plan and apply via `gcloud secrets versions access`"
  sensitive   = false
}
