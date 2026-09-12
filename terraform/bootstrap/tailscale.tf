# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Federation leaves nothing secret to store: the provider mints its own OIDC
# token and trades it for one good for an hour. What remains is the trust
# credential's client id, an identifier that grants nothing by itself.
#
# It lives here anyway because it does not exist until the credential is created
# by hand, which leaves terraform/alunduil/ nothing to read until then — the
# same reason the Git Sync App identifiers sit in Secret Manager rather than in
# a committed default.
resource "google_secret_manager_secret" "tailscale_client_id" {
  project   = google_project.env.project_id
  secret_id = "tailscale-client-id"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# One trust credential authenticates plan and apply alike, so both deployer SAs
# read it rather than splitting RO from RW the way the Cloudflare tokens do.
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
