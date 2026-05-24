# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

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
