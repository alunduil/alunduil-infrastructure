# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The read-only GitHub App behind the Grafana GitHub data source. The two
# identifiers reach terraform/alunduil/ through the deployers; the private key
# reaches Grafana only through scripts/set-grafana-github-credentials.sh, since
# a data source keeps its secure fields in bucket-readable state.
locals {
  grafana_github_app_identifiers = toset([
    "grafana-github-app-id",
    "grafana-github-app-installation-id",
  ])
}

# Empty shells. scripts/configure-grafana-github-secrets.sh adds the versions
# after this layer applies, so the private key never reaches this layer's state.
resource "google_secret_manager_secret" "grafana_github_app" {
  for_each = setunion(local.grafana_github_app_identifiers, ["grafana-github-app-private-key"])

  project   = google_project.env.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "grafana_github_app_ro" {
  for_each = local.grafana_github_app_identifiers

  project   = google_secret_manager_secret.grafana_github_app[each.value].project
  secret_id = google_secret_manager_secret.grafana_github_app[each.value].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

resource "google_secret_manager_secret_iam_member" "grafana_github_app_rw" {
  for_each = local.grafana_github_app_identifiers

  project   = google_secret_manager_secret.grafana_github_app[each.value].project
  secret_id = google_secret_manager_secret.grafana_github_app[each.value].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}
