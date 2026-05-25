# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The project itself and the three foundational APIs (iam,
# cloudresourcemanager, serviceusage) live in terraform/bootstrap/. The
# removed{} blocks below let `terraform apply` here forget them from main
# state without destroying. They can be deleted in a follow-up PR once the
# migration apply has happened.

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

# APIs required by managed resources in this config.
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
