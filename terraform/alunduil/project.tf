# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# APIs in use. services_to_disable.tf holds the rest.
resource "google_project_service" "kept" {
  for_each = toset([
    # Home Assistant's Calendar and Gemini integrations, through C-23 and C-24.
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
  from = google_project_service.legacy["calendar-json.googleapis.com"]
  to   = google_project_service.kept["calendar-json.googleapis.com"]
}

moved {
  from = google_project_service.legacy["generativelanguage.googleapis.com"]
  to   = google_project_service.kept["generativelanguage.googleapis.com"]
}
