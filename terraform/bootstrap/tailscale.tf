# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# A client id is an identifier, not a secret. Both live in Secret Manager
# because neither exists until its trust credential is created by hand, which
# leaves terraform/alunduil/ nothing to read until then.
#
# Split by role because plan runs on pull requests, and a pull request supplies
# the workflow that runs — Renovate edits those files whenever it bumps an
# action — so the id reachable from one grants no write.
# Each id is read by one deployer and no other. Driving the secret and its
# binding from one map keeps that pairing true: binding the read-only id to the
# apply service account would hand plan a write credential, and nothing else
# here would notice.
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
