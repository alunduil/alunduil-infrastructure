# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# APIs something in this layer depends on. services_to_disable.tf holds the rest.
resource "google_project_service" "kept" {
  for_each = toset([
    # The audit log-based metric is defined against logging; the Grafana data
    # source reads it back through monitoring.
    "logging.googleapis.com",
    "monitoring.googleapis.com",

    # Without this the Cloud Logging plugin's project picker comes up empty.
    "cloudresourcemanager.googleapis.com",

    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
  ])

  project = local.bootstrap.project_id
  service = each.key

  disable_on_destroy = false
}

moved {
  from = google_project_service.storage_api
  to   = google_project_service.kept["storage-api.googleapis.com"]
}

moved {
  from = google_project_service.storage_component
  to   = google_project_service.kept["storage-component.googleapis.com"]
}

moved {
  from = google_project_service.legacy["logging.googleapis.com"]
  to   = google_project_service.kept["logging.googleapis.com"]
}

moved {
  from = google_project_service.legacy["monitoring.googleapis.com"]
  to   = google_project_service.kept["monitoring.googleapis.com"]
}
