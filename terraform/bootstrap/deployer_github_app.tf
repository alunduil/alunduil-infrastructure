# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Plan runs whatever workflow a pull request supplies, so each deployer reads
# only its own App's credentials: plan the read-only App, apply the read-write.
locals {
  deployer_github_app_readers = {
    for pair in setproduct(["deployer-github-app-id", "deployer-github-app-private-key"], keys(local.deployers)) :
    "${pair[0]}-${pair[1]}" => pair[1]
  }
}

# Empty shells. scripts/configure-deployer-github-secrets.sh adds the versions
# after this layer applies, so the private keys never reach this layer's state.
resource "google_secret_manager_secret" "deployer_github_app" {
  for_each = local.deployer_github_app_readers

  project   = google_project.env.project_id
  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "deployer_github_app" {
  for_each = local.deployer_github_app_readers

  project   = google_secret_manager_secret.deployer_github_app[each.key].project
  secret_id = google_secret_manager_secret.deployer_github_app[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.deployers[each.value]}"
}
