# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Read-write deployer impersonated by `terraform apply` on merge to main.

resource "google_service_account" "github_deployer_rw" {
  project      = google_project.env.project_id
  account_id   = "github-deployer-rw"
  display_name = "GitHub Applier"
  description  = "GitHub Actions service account with write access for terraform apply"

  depends_on = [google_project_service.iam]
}

# Same surface as the RO role (serviceusage + resourcemanager.projects.get)
# extended with the mutate verbs. Notably omits billing.* — billing lives in
# bootstrap only, so CI never needs it.
resource "google_project_iam_custom_role" "github_deployer_rw_applier" {
  project     = google_project.env.project_id
  role_id     = "githubDeployerApplier"
  title       = "GitHub Deployer Applier"
  description = "Least-privilege role for terraform apply in CI"

  permissions = [
    "resourcemanager.projects.get",
    "serviceusage.services.disable",
    "serviceusage.services.enable",
    "serviceusage.services.get",
    "serviceusage.services.list",
    "serviceusage.services.use",
  ]

  depends_on = [google_project_service.serviceusage]
}

resource "google_project_iam_member" "github_deployer_rw_applier" {
  project = google_project.env.project_id
  role    = google_project_iam_custom_role.github_deployer_rw_applier.name
  member  = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}

# State-bucket access: read/write tfstate objects + list bucket contents.
resource "google_storage_bucket_iam_member" "github_deployer_rw_state_object_admin" {
  bucket = data.google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}

resource "google_storage_bucket_iam_member" "github_deployer_rw_state_bucket_reader" {
  bucket = data.google_storage_bucket.state.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}

# WIF principal bindings.
resource "google_service_account_iam_member" "github_deployer_rw_workload_identity_user" {
  service_account_id = google_service_account.github_deployer_rw.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wif_principal

  depends_on = [google_iam_workload_identity_pool_provider.github]
}

resource "google_service_account_iam_member" "github_deployer_rw_token_creator" {
  service_account_id = google_service_account.github_deployer_rw.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.wif_principal

  depends_on = [google_iam_workload_identity_pool_provider.github]
}
