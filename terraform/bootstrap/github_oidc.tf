# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

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
    "attribute.deployer"         = "assertion.job_workflow_ref in ${jsonencode(local.deployer_rw_workflow_refs)} ? '${local.deployer_rw}' : 'none'"
  }

  attribute_condition = "assertion.repository == '${local.repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Every job on main can request an OIDC token, so the RW deployer binds on the
# workflow that requested it rather than the ref. job_workflow_ref carries the
# repository, file, and ref.
#
# The provider's mapping and condition have to agree with the bindings below,
# and a disagreement between them fails the exchange silently.
locals {
  wif_pool_prefix = "principalSet://iam.googleapis.com/projects/${google_project.env.number}/locations/global/workloadIdentityPools"

  repository  = "alunduil/alunduil-infrastructure"
  deployer_rw = "rw"

  deployer_rw_workflow_refs = [
    "${local.repository}/.github/workflows/terraform-apply.yml@refs/heads/main",
  ]

  wif_principal             = "${local.wif_pool_prefix}/github/attribute.repository/${local.repository}"
  wif_principal_deployer_rw = "${local.wif_pool_prefix}/github/attribute.deployer/${local.deployer_rw}"
}
