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
# Each client id is read by one deployer and no other, unlike the Grafana
# secrets both read. Driving the secret and its binding from the same map is
# what keeps that pairing true: binding the read-only id to the apply SA would
# hand plan a write credential, and nothing else here would notice.
locals {
  tailscale_deployers = {
    ro = google_service_account.github_deployer_ro.email
    rw = google_service_account.github_deployer_rw.email
  }
}

resource "google_secret_manager_secret" "tailscale_client_id" {
  for_each = local.tailscale_deployers

  project   = google_project.env.project_id
  secret_id = "tailscale-client-id-${each.key}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "tailscale_client_id" {
  for_each = local.tailscale_deployers

  project   = google_secret_manager_secret.tailscale_client_id[each.key].project
  secret_id = google_secret_manager_secret.tailscale_client_id[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value}"
}

moved {
  from = google_secret_manager_secret_iam_member.tailscale_client_id_ro
  to   = google_secret_manager_secret_iam_member.tailscale_client_id["ro"]
}

moved {
  from = google_secret_manager_secret_iam_member.tailscale_client_id_rw
  to   = google_secret_manager_secret_iam_member.tailscale_client_id["rw"]
}
