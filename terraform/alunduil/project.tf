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

# Kept enabled because the audit log-based metric in gcp_observability.tf depends
# on it; moved out of services_to_disable.tf now that a managed resource uses it.
resource "google_project_service" "logging" {
  project = local.bootstrap.project_id
  service = "logging.googleapis.com"

  disable_on_destroy = false
}

moved {
  from = google_project_service.legacy["logging.googleapis.com"]
  to   = google_project_service.logging
}
