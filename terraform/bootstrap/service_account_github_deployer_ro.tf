# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Read-only deployer impersonated by `terraform plan` runs in CI.

resource "google_service_account" "github_deployer_ro" {
  project      = google_project.env.project_id
  account_id   = "github-deployer-ro"
  display_name = "GitHub Planner"
  description  = "GitHub Actions service account with read-only access for plan runs"

  depends_on = [google_project_service.iam]
}

# Scoped to the actual GCP surface terraform/alunduil/ touches after the
# bootstrap migration: serviceusage (storage_api/storage_component plus the
# legacy services_to_disable list) and resourcemanager.projects.get. DNS lives
# on Cloudflare and storage/IAM aren't managed in main today; add perms here
# when (and only when) a real resource needs them.
resource "google_project_iam_custom_role" "github_deployer_ro_planner" {
  project     = google_project.env.project_id
  role_id     = "githubDeployerPlanner"
  title       = "GitHub Deployer Planner"
  description = "Least-privilege read role for terraform plan in CI"

  permissions = [
    "resourcemanager.projects.get",
    "serviceusage.services.get",
    "serviceusage.services.list",
  ]

  depends_on = [google_project_service.serviceusage]
}

resource "google_project_iam_member" "github_deployer_ro_planner" {
  project = google_project.env.project_id
  role    = google_project_iam_custom_role.github_deployer_ro_planner.name
  member  = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

# State-bucket access: read tfstate objects + list bucket contents (the GCS
# backend needs both).
resource "google_storage_bucket_iam_member" "github_deployer_ro_state_object_viewer" {
  bucket = data.google_storage_bucket.state.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

resource "google_storage_bucket_iam_member" "github_deployer_ro_state_bucket_reader" {
  bucket = data.google_storage_bucket.state.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

# WIF principal bindings: allow the GitHub Actions OIDC principal to
# impersonate this service account and mint short-lived tokens for it.
resource "google_service_account_iam_member" "github_deployer_ro_workload_identity_user" {
  service_account_id = google_service_account.github_deployer_ro.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wif_principal

  depends_on = [google_iam_workload_identity_pool_provider.github]
}

resource "google_service_account_iam_member" "github_deployer_ro_token_creator" {
  service_account_id = google_service_account.github_deployer_ro.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.wif_principal

  depends_on = [google_iam_workload_identity_pool_provider.github]
}
