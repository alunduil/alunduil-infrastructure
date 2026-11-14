# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Lets exactly one GitHub Actions workflow read a fixed set of secrets.
#
# The pool is the workflow's own, not another provider in a shared pool:
# principalSet paths are pool-scoped, so no binding elsewhere can match a token
# this pool admits.

locals {
  workflow_segments = split("/", var.caller.workflow)

  # The provider's condition and the reader's binding both derive from
  # caller.workflow, because a disagreement between them fails the exchange
  # silently.
  principal_value = {
    repository       = join("/", slice(local.workflow_segments, 0, 2))
    repository_owner = local.workflow_segments[0]
  }[var.caller.principal_attribute]

  # job_workflow_ref, not workflow_ref, names the file the job is defined in.
  # A reusable workflow's jobs carry their caller's workflow_ref, so pinning that
  # would admit whatever the pinned workflow calls.
  ref_clause = (
    var.caller.ref == null
    ? "assertion.job_workflow_ref.startsWith('${var.caller.workflow}@')"
    : "assertion.job_workflow_ref == '${var.caller.workflow}@${var.caller.ref}'"
  )
}

resource "google_iam_workload_identity_pool" "this" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool.id
  display_name              = var.pool.display_name
  description               = var.pool.description
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "this" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.this.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub"
  description                        = var.pool.provider_description
  disabled                           = false

  attribute_mapping = {
    "google.subject"                              = "assertion.sub"
    "attribute.${var.caller.principal_attribute}" = "assertion.${var.caller.principal_attribute}"
  }

  attribute_condition = join(" && ", [
    "assertion.${var.caller.principal_attribute} == '${local.principal_value}'",
    local.ref_clause,
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "reader" {
  project      = var.project_id
  account_id   = var.service_account.account_id
  display_name = var.service_account.display_name
  description  = var.service_account.description
}

# workloadIdentityUser admits the federated identity; serviceAccountTokenCreator
# lets it generate the access token get-secretmanager-secrets calls with.
resource "google_service_account_iam_member" "reader" {
  for_each = toset([
    "roles/iam.workloadIdentityUser",
    "roles/iam.serviceAccountTokenCreator",
  ])

  service_account_id = google_service_account.reader.name
  role               = each.key
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.this.name}/attribute.${var.caller.principal_attribute}/${local.principal_value}"

  depends_on = [google_iam_workload_identity_pool_provider.this]
}

# The reader holds no project IAM; these grants are its entire authority.
resource "google_secret_manager_secret_iam_member" "reader" {
  for_each = var.secret_ids

  project   = var.project_id
  secret_id = each.key
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.reader.email}"
}
