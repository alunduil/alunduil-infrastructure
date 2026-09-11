# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The Tailscale provider can't create its own OAuth client, so the credential
# comes from a hand-created console client. Like the Grafana secrets there is no
# RO/RW split: one OAuth client authenticates both plan and apply, so both
# deployer SAs read both secrets. The per-secret accessor isolation from
# cloudflare_tokens.tf still holds — values never live in bucket-readable state,
# only behind secretAccessor IAM.
locals {
  tailscale_oauth_secrets = toset([
    "tailscale-oauth-client-id",
    "tailscale-oauth-client-secret",
  ])
}

# Empty shells. scripts/configure-tailscale-secrets.sh adds the versions after
# this layer applies: a version Terraform created would hold the credential in
# this layer's state, and would demand the client secret, which the console
# shows once, on every later run of the layer.
resource "google_secret_manager_secret" "tailscale_oauth" {
  for_each = local.tailscale_oauth_secrets

  project   = google_project.env.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "tailscale_oauth_ro" {
  for_each = google_secret_manager_secret.tailscale_oauth

  project   = each.value.project
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

resource "google_secret_manager_secret_iam_member" "tailscale_oauth_rw" {
  for_each = google_secret_manager_secret.tailscale_oauth

  project   = each.value.project
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}
