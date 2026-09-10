# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

resource "google_service_account" "github_deployer_rw" {
  project      = google_project.env.project_id
  account_id   = "github-deployer-rw"
  display_name = "GitHub Applier"
  description  = "GitHub Actions service account with write access for terraform apply"

  depends_on = [google_project_service.iam]
}

# Everything the planner may do, plus the verbs that change things. Add write
# permissions only when a real resource in terraform/alunduil/ needs them; a read
# permission belongs in deployer_ro_permissions, which this inherits. Omits
# billing.* — CI never needs it. Sorted so the role reads the same on every plan.
locals {
  deployer_rw_permissions = sort(concat(local.deployer_ro_permissions, [
    "logging.logMetrics.create",
    "logging.logMetrics.delete",
    "logging.logMetrics.update",
    "serviceusage.services.disable",
    "serviceusage.services.enable",
    "serviceusage.services.use",
  ]))
}

resource "google_project_iam_custom_role" "github_deployer_rw_applier" {
  project     = google_project.env.project_id
  role_id     = "githubDeployerApplier"
  title       = "GitHub Deployer Applier"
  description = "Least-privilege role for terraform apply in CI"

  permissions = local.deployer_rw_permissions

  depends_on = [google_project_service.serviceusage]
}

resource "google_project_iam_member" "github_deployer_rw_applier" {
  project = google_project.env.project_id
  role    = google_project_iam_custom_role.github_deployer_rw_applier.name
  member  = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}

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

resource "google_service_account_iam_member" "github_deployer_rw_workload_identity_user" {
  service_account_id = google_service_account.github_deployer_rw.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wif_principal_main

  depends_on = [google_iam_workload_identity_pool_provider.github]
}

resource "google_service_account_iam_member" "github_deployer_rw_token_creator" {
  service_account_id = google_service_account.github_deployer_rw.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.wif_principal_main

  depends_on = [google_iam_workload_identity_pool_provider.github]
}
