# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# APIs a managed resource in this layer depends on, so they stay enabled for as
# long as that resource exists. The counterpart set in services_to_disable.tf
# carries `disable_on_destroy = true` and nothing depends on it.
resource "google_project_service" "kept" {
  for_each = toset([
    # The audit log-based metric in gcp_observability.tf is defined against
    # logging; Grafana's Cloud Monitoring data source reads it back through
    # monitoring.
    "logging.googleapis.com",
    "monitoring.googleapis.com",

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
