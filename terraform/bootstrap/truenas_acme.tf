# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# TrueNAS's ACME DNS authenticator answers DNS-01 challenges for
# truenas.alunduil.com by writing _acme-challenge TXT records.
#
# This lives in bootstrap because creating a Cloudflare token needs
# `User:API Tokens` Edit, which only the bootstrap token (C-07) carries.
#
# No expires_on: an expired token fails renewal silently until the certificate
# lapses. Rotation is a bootstrap re-run followed by
# docs/how-to/configure-truenas-acme-token.md.
resource "cloudflare_api_token" "truenas_acme" {
  name = "truenas-acme"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = data.cloudflare_api_token_permission_groups_list.zone_read.result[0].id },
      { id = data.cloudflare_api_token_permission_groups_list.dns_write.result[0].id },
    ]
    resources = local.alunduil_com_zone_resource
  }]
}

# No secretAccessor binding: the consumer is A-01, which an operator configures
# by hand, and no deployer needs DNS write on the zone through this token.
resource "google_secret_manager_secret" "cloudflare_api_token_truenas_acme" {
  project   = google_project.env.project_id
  secret_id = "cloudflare-api-token-truenas-acme"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "cloudflare_api_token_truenas_acme" {
  secret      = google_secret_manager_secret.cloudflare_api_token_truenas_acme.id
  secret_data = cloudflare_api_token.truenas_acme.value
}
