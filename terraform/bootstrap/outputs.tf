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

# configure-github-secrets.sh publishes these to blog.alunduil.com as Actions
# secrets; its Pages build reads them by name.
output "blog_analytics_workload_identity_provider" {
  value       = module.blog_analytics_reader.workload_identity_provider
  description = "Full resource name of the blog's WIF provider, e.g. projects/<num>/locations/global/workloadIdentityPools/blog/providers/github-provider"
  sensitive   = false
}

output "blog_analytics_reader_email" {
  value       = module.blog_analytics_reader.service_account_email
  description = "Email of the service account blog.alunduil.com's Pages build impersonates"
  sensitive   = false
}

output "cloudflare_api_token_blog_analytics_ro_secret" {
  value       = google_secret_manager_secret.cloudflare_api_token_blog_analytics_ro.secret_id
  description = "Secret Manager short name holding the blog's Cloudflare analytics token; fetched at build time by the blog's Pages workflow"
  sensitive   = false
}

# renovate-config's fix-renovate-hooks.yml hard-codes these.
output "hook_fix_workload_identity_provider" {
  value       = module.hook_fix_reader.workload_identity_provider
  description = "Full resource name of the hook-fix WIF provider, e.g. projects/<num>/locations/global/workloadIdentityPools/hook-fix/providers/github-provider"
  sensitive   = false
}

output "hook_fix_reader_email" {
  value       = module.hook_fix_reader.service_account_email
  description = "Email of the service account the reusable hook-fix workflow impersonates"
  sensitive   = false
}

output "hook_fix_app_secrets" {
  value       = sort([for secret in google_secret_manager_secret.hook_fix_app : secret.secret_id])
  description = "Secret Manager short names holding the hook-fix GitHub App ID and private key; populated by scripts/configure-hook-fix-secrets.sh and fetched by the reusable hook-fix workflow"
  sensitive   = false
}

# renovate-config's hook-fix-selftest.yml hard-codes these.
output "hook_fix_selftest_workload_identity_provider" {
  value       = module.hook_fix_selftest_reader.workload_identity_provider
  description = "Full resource name of the hook-fix self-test WIF provider, e.g. projects/<num>/locations/global/workloadIdentityPools/hook-fix-selftest/providers/github-provider"
  sensitive   = false
}

output "hook_fix_selftest_reader_email" {
  value       = module.hook_fix_selftest_reader.service_account_email
  description = "Email of the service account renovate-config's hook-fix self-test impersonates"
  sensitive   = false
}

output "hook_fix_selftest_app_secrets" {
  value       = sort([for secret in google_secret_manager_secret.hook_fix_selftest_app : secret.secret_id])
  description = "Secret Manager short names holding the hook-fix self-test GitHub App ID and private key; populated by scripts/configure-hook-fix-selftest-secrets.sh and fetched by renovate-config's hook-fix self-test"
  sensitive   = false
}

output "terraform_github_app_secrets" {
  value       = sort([for secret in google_secret_manager_secret.terraform_github_app : secret.secret_id])
  description = "Secret Manager short names holding the Terraform GitHub Apps' IDs and private keys, read-only for plan and read-write for apply; populated by scripts/configure-terraform-github-secrets.sh and fetched by scripts/export-terraform-credentials.sh"
  sensitive   = false
}

# Grafana Git Sync inputs for terraform/alunduil/. The stack coordinates reach
# the alunduil layer through the published bootstrap-outputs.json object (see
# published_outputs.tf); the App's three values are fetched from Secret Manager
# by the plan and apply workflows.
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

output "grafana_provisioner_token_secret" {
  value       = google_secret_manager_secret.grafana_provisioner_token.secret_id
  description = "Secret Manager short name holding the Grafana provisioning service-account token; fetched at plan and apply time via `gcloud secrets versions access`"
  sensitive   = false
}

output "grafana_git_sync_app_secrets" {
  value       = sort([for secret in google_secret_manager_secret.grafana_git_sync_app : secret.secret_id])
  description = "Secret Manager short names holding the Git Sync GitHub App ID, installation ID, and private key; populated by scripts/configure-git-sync-secrets.sh and fetched at plan and apply time via `gcloud secrets versions access`"
  sensitive   = false
}

output "grafana_github_app_secrets" {
  value       = sort([for secret in google_secret_manager_secret.grafana_github_app : secret.secret_id])
  description = "Secret Manager short names holding the Grafana GitHub data source App ID, installation ID, and private key; populated by scripts/configure-grafana-github-secrets.sh. Plan and apply read the two IDs; scripts/set-grafana-github-credentials.sh reads the key"
  sensitive   = false
}

output "grafana_deployer_token_secrets" {
  value       = sort([for secret in google_secret_manager_secret.grafana_deployer_token : secret.secret_id])
  description = "Secret Manager short names holding the Fleet Management and Adaptive Metrics access-policy tokens, read-only for plan and read-write for apply; fetched via `gcloud secrets versions access`"
  sensitive   = false
}

output "grafana_alloy_push_token_secrets" {
  value       = { for collector, secret in google_secret_manager_secret.grafana_alloy_push_token : collector => secret.secret_id }
  description = "Secret Manager short name of each collector's alloy push token, keyed by collector; read by an operator rather than CI, and set on the collector as GCLOUD_RW_API_KEY"
  sensitive   = false
}

output "grafana_gcp_reader_email" {
  value       = google_service_account.grafana_gcp_reader.email
  description = "Email of the read-only SA Grafana Cloud authenticates as; the alunduil layer uses it as the data-source clientEmail"
  sensitive   = false
}

output "grafana_gcp_reader_key_secret" {
  value       = google_secret_manager_secret.grafana_gcp_reader_key.secret_id
  description = "Secret Manager short name holding the Grafana GCP reader SA key"
  sensitive   = false
}

output "tailscale_client_id_secrets" {
  value       = sort([for secret in google_secret_manager_secret.tailscale_client_id : secret.secret_id])
  description = "Secret Manager short names holding the Tailscale trust credential client IDs, read-only for plan and read-write for apply; populated by scripts/configure-tailscale-secrets.sh and fetched via `gcloud secrets versions access`"
  sensitive   = false
}

# configure-github-secrets.sh publishes these to alunduil/release-gate as Actions
# secrets; its deploy workflow reads them by name.
output "release_gate_workload_identity_provider" {
  value       = module.release_gate_reader.workload_identity_provider
  description = "Full resource name of the release gate's WIF provider, e.g. projects/<num>/locations/global/workloadIdentityPools/release-gate/providers/github-provider"
  sensitive   = false
}

output "release_gate_reader_email" {
  value       = module.release_gate_reader.service_account_email
  description = "Email of the service account the release gate's deploy workflow impersonates"
  sensitive   = false
}

output "release_gate_app_private_key_secret" {
  value       = google_secret_manager_secret.release_gate["app_private_key"].secret_id
  description = "Secret Manager short name holding the release gate App's private key; populated by scripts/configure-release-gate-secrets.sh"
  sensitive   = false
}

output "release_gate_webhook_secret_secret" {
  value       = google_secret_manager_secret.release_gate["webhook_secret"].secret_id
  description = "Secret Manager short name holding the release gate App's webhook secret"
  sensitive   = false
}

output "cloudflare_api_token_release_gate_deploy_secret" {
  value       = google_secret_manager_secret.release_gate["deploy_token"].secret_id
  description = "Secret Manager short name holding the Cloudflare token the release gate's deploy workflow deploys its Worker with"
  sensitive   = false
}
