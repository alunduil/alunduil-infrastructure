# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The client id is an identifier, not a secret. It lives in Secret Manager
# because it does not exist until the trust credential is created by hand, which
# leaves terraform/alunduil/ nothing to read until then.
resource "google_secret_manager_secret" "tailscale_client_id" {
  project   = google_project.env.project_id
  secret_id = "tailscale-client-id"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# One trust credential authenticates plan and apply alike, so both deployer SAs
# read it.
resource "google_secret_manager_secret_iam_member" "tailscale_client_id_ro" {
  project   = google_secret_manager_secret.tailscale_client_id.project
  secret_id = google_secret_manager_secret.tailscale_client_id.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

resource "google_secret_manager_secret_iam_member" "tailscale_client_id_rw" {
  project   = google_secret_manager_secret.tailscale_client_id.project
  secret_id = google_secret_manager_secret.tailscale_client_id.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}
