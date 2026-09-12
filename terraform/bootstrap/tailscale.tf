# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# A client id is an identifier, not a secret. Both live in Secret Manager
# because neither exists until its trust credential is created by hand, which
# leaves terraform/alunduil/ nothing to read until then.
#
# Split by role the way the Cloudflare tokens are, and for the same reason
# Grafana cannot be: Tailscale grants read scopes, so plan needs no write. Plan
# runs on pull requests, and a pull request can edit the workflow that holds the
# credential — Renovate edits those files routinely — so the credential reachable
# from a pull request is the read-only one.
resource "google_secret_manager_secret" "tailscale_client_id" {
  for_each = toset(["ro", "rw"])

  project   = google_project.env.project_id
  secret_id = "tailscale-client-id-${each.value}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "tailscale_client_id_ro" {
  project   = google_secret_manager_secret.tailscale_client_id["ro"].project
  secret_id = google_secret_manager_secret.tailscale_client_id["ro"].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

resource "google_secret_manager_secret_iam_member" "tailscale_client_id_rw" {
  project   = google_secret_manager_secret.tailscale_client_id["rw"].project
  secret_id = google_secret_manager_secret.tailscale_client_id["rw"].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}
