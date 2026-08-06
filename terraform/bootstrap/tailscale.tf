# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The Tailscale provider can't create its own OAuth client, so the credential
# comes from a hand-created console client fed in as a variable, not from a
# Terraform-managed resource. Like the Grafana secrets there is no RO/RW split:
# one OAuth client authenticates both plan and apply, so both deployer SAs read
# both secrets. The per-secret accessor isolation from cloudflare_tokens.tf
# still holds — values never live in bucket-readable state, only behind
# secretAccessor IAM.
resource "google_secret_manager_secret" "tailscale_oauth_client_id" {
  project   = google_project.env.project_id
  secret_id = "tailscale-oauth-client-id"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "tailscale_oauth_client_id" {
  secret      = google_secret_manager_secret.tailscale_oauth_client_id.id
  secret_data = var.tailscale_oauth_client_id
}

resource "google_secret_manager_secret_iam_member" "tailscale_oauth_client_id_ro" {
  project   = google_secret_manager_secret.tailscale_oauth_client_id.project
  secret_id = google_secret_manager_secret.tailscale_oauth_client_id.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

resource "google_secret_manager_secret_iam_member" "tailscale_oauth_client_id_rw" {
  project   = google_secret_manager_secret.tailscale_oauth_client_id.project
  secret_id = google_secret_manager_secret.tailscale_oauth_client_id.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}

resource "google_secret_manager_secret" "tailscale_oauth_client_secret" {
  project   = google_project.env.project_id
  secret_id = "tailscale-oauth-client-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "tailscale_oauth_client_secret" {
  secret      = google_secret_manager_secret.tailscale_oauth_client_secret.id
  secret_data = var.tailscale_oauth_client_secret
}

resource "google_secret_manager_secret_iam_member" "tailscale_oauth_client_secret_ro" {
  project   = google_secret_manager_secret.tailscale_oauth_client_secret.project
  secret_id = google_secret_manager_secret.tailscale_oauth_client_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

resource "google_secret_manager_secret_iam_member" "tailscale_oauth_client_secret_rw" {
  project   = google_secret_manager_secret.tailscale_oauth_client_secret.project
  secret_id = google_secret_manager_secret.tailscale_oauth_client_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}
