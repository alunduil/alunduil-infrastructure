# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The alunduil project is the single GCP project for all personal infrastructure.
# It was created before Terraform; import with:
#   terraform import google_project.env alunduil
resource "google_project" "env" {
  name                = "alunduil"
  project_id          = "alunduil"
  auto_create_network = false
  billing_account     = var.billing_account_id

  labels = {
    environment           = "production"
    created_by            = "bootstrap"
    managed_by            = "terraform"
    "generative-language" = "enabled"
  }

  # auto_create_network cannot be changed after project creation.
  # The alunduil project was created before Terraform and has a default network.
  lifecycle {
    ignore_changes = [auto_create_network]
  }
}

# Foundational APIs required before any other resources can be managed
resource "google_project_service" "iam" {
  project = google_project.env.project_id
  service = "iam.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "cloudresourcemanager" {
  project = google_project.env.project_id
  service = "cloudresourcemanager.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.iam]
}

resource "google_project_service" "serviceusage" {
  project = google_project.env.project_id
  service = "serviceusage.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.iam]
}

# APIs required by managed resources
resource "google_project_service" "storage_api" {
  project = google_project.env.project_id
  service = "storage-api.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.serviceusage]
}

resource "google_project_service" "storage_component" {
  project = google_project.env.project_id
  service = "storage-component.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.serviceusage]
}
