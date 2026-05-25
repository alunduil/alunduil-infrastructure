# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

removed {
  from = google_project.env

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_service.iam

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_service.cloudresourcemanager

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_service.serviceusage

  lifecycle {
    destroy = false
  }
}

resource "google_project_service" "storage_api" {
  project = data.terraform_remote_state.bootstrap.outputs.project_id
  service = "storage-api.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "storage_component" {
  project = data.terraform_remote_state.bootstrap.outputs.project_id
  service = "storage-component.googleapis.com"

  disable_on_destroy = false
}
