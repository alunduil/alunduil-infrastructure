# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
# Static website hosting buckets for blog.alunduil.com
# These are legacy GCS buckets created before this Terraform configuration.
# ACL-based access control prevents metadata reads; the exact configuration
# (website suffix, CORS, lifecycle) will appear in terraform plan after import.

import {
  to = google_storage_bucket.blog
  id = "blog.alunduil.com"
}

resource "google_storage_bucket" "blog" {
  name          = "blog.alunduil.com"
  location      = "US"
  force_destroy = false

  depends_on = [
    google_project_service.storage_api,
    google_project_service.storage_component,
  ]
}

import {
  to = google_storage_bucket.d_blog
  id = "d.blog.alunduil.com"
}

resource "google_storage_bucket" "d_blog" {
  name          = "d.blog.alunduil.com"
  location      = "US"
  force_destroy = false

  depends_on = [
    google_project_service.storage_api,
    google_project_service.storage_component,
  ]
}

import {
  to = google_storage_bucket.r_blog
  id = "r.blog.alunduil.com"
}

resource "google_storage_bucket" "r_blog" {
  name          = "r.blog.alunduil.com"
  location      = "US"
  force_destroy = false

  depends_on = [
    google_project_service.storage_api,
    google_project_service.storage_component,
  ]
}
