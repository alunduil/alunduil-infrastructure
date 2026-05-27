# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Identity and storage for the hourly Inbox sync (sync-inbox-project.yml).
# A dedicated SA isolates the workflow's secretAccessor grant from the
# RO/RW deployer identities used for terraform plan/apply.
#
# The PAT itself is operator-minted (GitHub has no API to provision
# fine-grained PATs) and pasted into Secret Manager once after the first
# apply:
#
#   gh auth refresh -s project,read:project  # if minting via the CLI
#   gcloud secrets versions add inbox-sync-token \
#     --project=alunduil --data-file=-

resource "google_service_account" "github_deployer_sync" {
  project      = google_project.env.project_id
  account_id   = "github-deployer-sync"
  display_name = "GitHub Inbox Sync"
  description  = "GitHub Actions service account for the hourly Inbox sync workflow"

  depends_on = [google_project_service.iam]
}

resource "google_service_account_iam_member" "github_deployer_sync_workload_identity_user" {
  service_account_id = google_service_account.github_deployer_sync.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wif_principal

  depends_on = [google_iam_workload_identity_pool_provider.github]
}

resource "google_service_account_iam_member" "github_deployer_sync_token_creator" {
  service_account_id = google_service_account.github_deployer_sync.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.wif_principal

  depends_on = [google_iam_workload_identity_pool_provider.github]
}

resource "google_secret_manager_secret" "inbox_sync_token" {
  project   = google_project.env.project_id
  secret_id = "inbox-sync-token"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "inbox_sync_token_accessor" {
  project   = google_secret_manager_secret.inbox_sync_token.project
  secret_id = google_secret_manager_secret.inbox_sync_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_sync.email}"
}
