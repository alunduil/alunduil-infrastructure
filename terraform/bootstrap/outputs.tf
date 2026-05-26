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

output "cloudflare_api_token_deployer_ro" {
  value       = cloudflare_api_token.deployer_ro.value
  description = "Cloudflare API token value for the RO deployer (Zone Read + DNS Read + Zone Settings Read on alunduil.com)"
  sensitive   = true
}

output "cloudflare_api_token_deployer_rw" {
  value       = cloudflare_api_token.deployer_rw.value
  description = "Cloudflare API token value for the RW deployer (Zone Read + DNS Write + Zone Settings Write on alunduil.com)"
  sensitive   = true
}
