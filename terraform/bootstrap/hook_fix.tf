# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The hook-fix App's credentials, read at runtime by renovate-config's
# fix-renovate-hooks.yml.

locals {
  hook_fix_app_secrets = toset([
    "hook-fix-app-id",
    "hook-fix-app-private-key",
  ])

  hook_fix_owner = "alunduil"
  hook_fix_workflow      = "${local.hook_fix_owner}/renovate-config/.github/workflows/fix-renovate-hooks.yml"
  hook_fix_wif_principal = "${local.wif_pool_prefix}/${google_iam_workload_identity_pool.hook_fix.workload_identity_pool_id}/attribute.repository_owner/${local.hook_fix_owner}"
}

# Empty shells. scripts/configure-hook-fix-secrets.sh adds the versions after
# this layer applies, so the private key never reaches this layer's state.
resource "google_secret_manager_secret" "hook_fix_app" {
  for_each = local.hook_fix_app_secrets

  project   = google_project.env.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# Its own pool. principalSet paths are pool-scoped, so no `github` binding can
# match a calling repository's token.
resource "google_iam_workload_identity_pool" "hook_fix" {
  project                   = google_project.env.project_id
  workload_identity_pool_id = "hook-fix"
  display_name              = "Hook fix"
  description               = "Workload Identity Pool for the reusable hook-fix workflow"
  disabled                  = false

  depends_on = [google_project_service.sts]
}

resource "google_iam_workload_identity_pool_provider" "hook_fix" {
  project                            = google_project.env.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.hook_fix.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub"
  description                        = "OIDC provider for the reusable hook-fix workflow"
  disabled                           = false

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # job_workflow_ref names the called workflow at the SHA its caller pins, so
  # only a prefix can match. That admits every ref of the file in
  # renovate-config, branches included.
  attribute_condition = join(" && ", [
    "assertion.repository_owner == '${local.hook_fix_owner}'",
    "assertion.job_workflow_ref.startsWith('${local.hook_fix_workflow}@')",
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "hook_fix_reader" {
  project      = google_project.env.project_id
  account_id   = "hook-fix-reader"
  display_name = "Hook-fix App Reader"
  description  = "Identity the reusable hook-fix workflow federates into to read the hook-fix App's credentials"

  depends_on = [google_project_service.iam]
}

resource "google_service_account_iam_member" "hook_fix_reader" {
  for_each = toset([
    "roles/iam.workloadIdentityUser",
    "roles/iam.serviceAccountTokenCreator",
  ])

  service_account_id = google_service_account.hook_fix_reader.name
  role               = each.key
  member             = local.hook_fix_wif_principal

  depends_on = [google_iam_workload_identity_pool_provider.hook_fix]
}

# The reader holds no project IAM; these grants are its entire authority.
resource "google_secret_manager_secret_iam_member" "hook_fix_app_reader" {
  for_each = google_secret_manager_secret.hook_fix_app

  project   = each.value.project
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.hook_fix_reader.email}"
}
