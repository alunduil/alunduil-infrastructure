# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# One OAuth client authenticates plan and apply alike, so both deployer SAs read
# both secrets rather than splitting RO from RW the way the Cloudflare tokens do.
locals {
  tailscale_oauth_secrets = toset([
    "tailscale-oauth-client-id",
    "tailscale-oauth-client-secret",
  ])
}

# Empty shells; scripts/configure-tailscale-secrets.sh adds the versions. A
# version Terraform created would hold the credential in this layer's state and
# would demand the client secret, which the console shows once, on every later
# run of the layer.
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
