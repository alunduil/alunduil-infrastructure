# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

data "cloudflare_api_token_permission_groups_list" "zone_read" {
  name  = "Zone Read"
  scope = "com.cloudflare.api.account.zone"
}

data "cloudflare_api_token_permission_groups_list" "dns_read" {
  name  = "DNS Read"
  scope = "com.cloudflare.api.account.zone"
}

data "cloudflare_api_token_permission_groups_list" "dns_write" {
  name  = "DNS Write"
  scope = "com.cloudflare.api.account.zone"
}

data "cloudflare_api_token_permission_groups_list" "zone_settings_read" {
  name  = "Zone Settings Read"
  scope = "com.cloudflare.api.account.zone"
}

data "cloudflare_api_token_permission_groups_list" "zone_settings_write" {
  name  = "Zone Settings Write"
  scope = "com.cloudflare.api.account.zone"
}

locals {
  alunduil_com_zone_resource = jsonencode({
    "com.cloudflare.api.account.zone.0ee2520bb84646200856ade7817daf2f" = "*" # pragma: allowlist secret
  })
}

resource "cloudflare_api_token" "deployer_ro" {
  name = "alunduil-infrastructure deployer (RO)"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = data.cloudflare_api_token_permission_groups_list.zone_read.result[0].id },
      { id = data.cloudflare_api_token_permission_groups_list.dns_read.result[0].id },
      { id = data.cloudflare_api_token_permission_groups_list.zone_settings_read.result[0].id },
    ]
    resources = local.alunduil_com_zone_resource
  }]
}

resource "cloudflare_api_token" "deployer_rw" {
  name = "alunduil-infrastructure deployer (RW)"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = data.cloudflare_api_token_permission_groups_list.zone_read.result[0].id },
      { id = data.cloudflare_api_token_permission_groups_list.dns_write.result[0].id },
      { id = data.cloudflare_api_token_permission_groups_list.zone_settings_write.result[0].id },
    ]
    resources = local.alunduil_com_zone_resource
  }]
}

# The deployer SAs hold `objectViewer`/`objectAdmin` on the shared
# `alunduil-tfstate` bucket, which means anything that lands a plan job
# could `gsutil cat` bootstrap state. Holding token values directly in
# state — even with `sensitive = true` — leaks them at that layer. Per-
# secret accessor IAM moves the authorization check off the bucket and
# onto each secret: RO SA reaches only the RO token, RW SA only the RW.
resource "google_secret_manager_secret" "cloudflare_api_token_deployer_ro" {
  project   = google_project.env.project_id
  secret_id = "cloudflare-api-token-deployer-ro"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "cloudflare_api_token_deployer_ro" {
  secret      = google_secret_manager_secret.cloudflare_api_token_deployer_ro.id
  secret_data = cloudflare_api_token.deployer_ro.value
}

resource "google_secret_manager_secret_iam_member" "cloudflare_api_token_deployer_ro_accessor" {
  project   = google_secret_manager_secret.cloudflare_api_token_deployer_ro.project
  secret_id = google_secret_manager_secret.cloudflare_api_token_deployer_ro.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

resource "google_secret_manager_secret" "cloudflare_api_token_deployer_rw" {
  project   = google_project.env.project_id
  secret_id = "cloudflare-api-token-deployer-rw"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "cloudflare_api_token_deployer_rw" {
  secret      = google_secret_manager_secret.cloudflare_api_token_deployer_rw.id
  secret_data = cloudflare_api_token.deployer_rw.value
}

resource "google_secret_manager_secret_iam_member" "cloudflare_api_token_deployer_rw_accessor" {
  project   = google_secret_manager_secret.cloudflare_api_token_deployer_rw.project
  secret_id = google_secret_manager_secret.cloudflare_api_token_deployer_rw.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}
