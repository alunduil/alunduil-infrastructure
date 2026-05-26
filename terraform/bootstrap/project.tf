# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

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

  lifecycle {
    ignore_changes  = [auto_create_network]
    prevent_destroy = true
  }
}

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
