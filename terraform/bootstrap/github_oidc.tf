# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Workload Identity Federation lets GitHub Actions exchange its OIDC token for
# short-lived GCP credentials, replacing long-lived service-account keys. The
# attribute_condition pins token acceptance to this single repository.

resource "google_project_service" "sts" {
  project = google_project.env.project_id
  service = "sts.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.serviceusage]
}

resource "google_project_service" "iam_credentials" {
  project = google_project.env.project_id
  service = "iamcredentials.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.serviceusage]
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.env.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  description               = "Workload Identity Pool for GitHub Actions"
  disabled                  = false

  depends_on = [google_project_service.sts]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.env.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub"
  description                        = "OIDC provider for GitHub Actions"
  disabled                           = false

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.environment"      = "assertion.environment"
  }

  attribute_condition = "assertion.repository == 'alunduil/alunduil-infrastructure'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Principal that both deployer SAs accept impersonation from.
locals {
  wif_principal = "principalSet://iam.googleapis.com/projects/${google_project.env.number}/locations/global/workloadIdentityPools/github/attribute.repository/alunduil/alunduil-infrastructure"
}
