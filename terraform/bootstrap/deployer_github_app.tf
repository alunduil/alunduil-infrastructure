# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The deployer GitHub Apps that authenticate the github provider in CI: a
# read-only App for plan and a read-write App for apply. Each deployer reads its
# own App's ID and key and no other, so a pull request's plan, which runs the
# workflow the pull request supplies, never reaches a write key.
locals {
  deployer_github_app_secrets = {
    for pair in setproduct(["deployer-github-app-id", "deployer-github-app-private-key"], keys(local.deployers)) :
    "${pair[0]}-${pair[1]}" => pair[1]
  }
}

# Empty shells. scripts/configure-deployer-github-secrets.sh adds the versions
# after this layer applies, so the private keys never reach this layer's state.
resource "google_secret_manager_secret" "deployer_github_app" {
  for_each = local.deployer_github_app_secrets

  project   = google_project.env.project_id
  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "deployer_github_app" {
  for_each = local.deployer_github_app_secrets

  project   = google_secret_manager_secret.deployer_github_app[each.key].project
  secret_id = google_secret_manager_secret.deployer_github_app[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.deployers[each.value]}"
}
