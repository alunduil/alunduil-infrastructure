# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

resource "google_project_service" "storage_api" {
  project = local.bootstrap.project_id
  service = "storage-api.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "storage_component" {
  project = local.bootstrap.project_id
  service = "storage-component.googleapis.com"

  disable_on_destroy = false
}

# The audit log-based metric in gcp_observability.tf is defined against this API,
# and Grafana's Cloud Monitoring data source reads the metric back through the
# monitoring one. Both stay enabled for as long as that path exists.
resource "google_project_service" "logging" {
  project = local.bootstrap.project_id
  service = "logging.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "monitoring" {
  project = local.bootstrap.project_id
  service = "monitoring.googleapis.com"

  disable_on_destroy = false
}

moved {
  from = google_project_service.legacy["logging.googleapis.com"]
  to   = google_project_service.logging
}

moved {
  from = google_project_service.legacy["monitoring.googleapis.com"]
  to   = google_project_service.monitoring
}
