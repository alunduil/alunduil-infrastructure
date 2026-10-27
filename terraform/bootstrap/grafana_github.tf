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

  grafana_github_app_secrets = setunion(
    local.grafana_github_app_identifiers,
    ["grafana-github-app-private-key"],
  )

  # Every deployer reads every identifier: plan and apply both need them.
  grafana_github_app_readers = {
    for pair in setproduct(local.grafana_github_app_identifiers, keys(local.deployers)) :
    "${pair[0]}-${pair[1]}" => { secret = pair[0], deployer = pair[1] }
  }
}

# Empty shells. scripts/configure-grafana-github-secrets.sh adds the versions
# after this layer applies, so the private key never reaches this layer's state.
resource "google_secret_manager_secret" "grafana_github_app" {
  for_each = local.grafana_github_app_secrets

  project   = google_project.env.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "grafana_github_app" {
  for_each = local.grafana_github_app_readers

  project   = google_secret_manager_secret.grafana_github_app[each.value.secret].project
  secret_id = google_secret_manager_secret.grafana_github_app[each.value.secret].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.deployers[each.value.deployer]}"
}
