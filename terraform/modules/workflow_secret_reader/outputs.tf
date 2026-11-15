# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

output "workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.this.name
  description = "Full resource name of the provider, for google-github-actions/auth's workload_identity_provider."
}

output "service_account_email" {
  value       = google_service_account.reader.email
  description = "Email of the reader service account, for google-github-actions/auth's service_account."
}
