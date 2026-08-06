# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Read-only service account Grafana Cloud authenticates as to query GCP directly
# at dashboard/alert time — Cloud Monitoring for metrics, Cloud Logging for logs.
# No data is ingested; the terraform/alunduil layer wires the Grafana data
# sources that use this identity.
#
# The key lives here rather than in the alunduil layer because a Grafana data
# source stores its credential in Terraform state (there is no write-only field
# like the Git Sync App key uses), and Grafana Cloud offers no keyless/workload-
# identity path for this data source. Keeping the key in the IAM-isolated
# bootstrap state — never in the bucket-readable alunduil state — preserves the
# per-secret isolation the rest of this layer relies on. The credential reaches
# Grafana out of band from Secret Manager (scripts/set-grafana-gcp-credentials.sh),
# so it never enters the alunduil state.
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
