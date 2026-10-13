# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# APIs something in this layer depends on. services_to_disable.tf holds the rest.
resource "google_project_service" "kept" {
  for_each = toset([
    # Home Assistant's Google Calendar and Google Gemini integrations.
    "calendar-json.googleapis.com",
    "generativelanguage.googleapis.com",

    # The audit log-based metric is defined against logging; the Grafana data
    # source reads it back through monitoring.
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

moved {
  from = google_project_service.legacy["calendar-json.googleapis.com"]
  to   = google_project_service.kept["calendar-json.googleapis.com"]
}

moved {
  from = google_project_service.legacy["generativelanguage.googleapis.com"]
  to   = google_project_service.kept["generativelanguage.googleapis.com"]
}
