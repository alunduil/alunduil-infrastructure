# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Read-only identity Grafana Cloud authenticates as to query GCP at dashboard
# time. Nothing is ingested; the alunduil layer wires the data sources that use
# it.
#
# The key lives in this layer because a Grafana data source keeps its credential
# in Terraform state — the provider offers no write-only field for it, and
# Grafana Cloud no keyless path — and only this layer's state is closed to the
# deployer service accounts. scripts/set-grafana-gcp-credentials.sh carries the
# key from Secret Manager to Grafana.
resource "google_service_account" "grafana_gcp_reader" {
  project      = google_project.env.project_id
  account_id   = "grafana-gcp-reader"
  display_name = "Grafana GCP Reader"
  description  = "Read-only identity Grafana Cloud uses to query Cloud Monitoring and Cloud Logging"

  depends_on = [google_project_service.iam]
}

resource "google_project_iam_member" "grafana_gcp_reader" {
  for_each = toset([
    "roles/monitoring.viewer",
    "roles/logging.viewer",
    "roles/logging.viewAccessor",
  ])

  project = google_project.env.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.grafana_gcp_reader.email}"
}

resource "google_service_account_key" "grafana_gcp_reader" {
  service_account_id = google_service_account.grafana_gcp_reader.name
}

resource "google_secret_manager_secret" "grafana_gcp_reader_key" {
  project   = google_project.env.project_id
  secret_id = "grafana-gcp-reader-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "grafana_gcp_reader_key" {
  secret      = google_secret_manager_secret.grafana_gcp_reader_key.id
  secret_data = base64decode(google_service_account_key.grafana_gcp_reader.private_key)
}
