# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The hook-fix self-test App's credentials, read at runtime by renovate-config's
# hook-fix-selftest.yml to open the pull requests it tests fix-renovate-hooks.yml
# against.

locals {
  hook_fix_selftest_app_secrets = toset([
    "hook-fix-selftest-app-id",
    "hook-fix-selftest-app-private-key",
  ])

  hook_fix_selftest_repository    = "alunduil/renovate-config"
  hook_fix_selftest_workflow      = "${local.hook_fix_selftest_repository}/.github/workflows/hook-fix-selftest.yml"
  hook_fix_selftest_wif_principal = "${local.wif_pool_prefix}/${google_iam_workload_identity_pool.hook_fix_selftest.workload_identity_pool_id}/attribute.repository/${local.hook_fix_selftest_repository}"
}

# Empty shells. scripts/configure-hook-fix-selftest-secrets.sh adds the versions
# after this layer applies, so the private key never reaches this layer's state.
resource "google_secret_manager_secret" "hook_fix_selftest_app" {
  for_each = local.hook_fix_selftest_app_secrets

  project   = google_project.env.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# Its own pool, so neither the hook-fix workflow nor a `github` binding can
# match this principalSet.
resource "google_iam_workload_identity_pool" "hook_fix_selftest" {
  project                   = google_project.env.project_id
  workload_identity_pool_id = "hook-fix-selftest"
  display_name              = "Hook fix self-test"
  description               = "Workload Identity Pool for renovate-config's hook-fix self-test"
  disabled                  = false

  depends_on = [google_project_service.sts]
}

resource "google_iam_workload_identity_pool_provider" "hook_fix_selftest" {
  project                            = google_project.env.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.hook_fix_selftest.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub"
  description                        = "OIDC provider for renovate-config's hook-fix self-test"
  disabled                           = false

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # job_workflow_ref rather than workflow_ref: the self-test calls
  # fix-renovate-hooks.yml, whose jobs share the caller's workflow_ref. Any ref
  # matches, so a pull request's own copy of the self-test can authenticate.
  attribute_condition = join(" && ", [
    "assertion.repository == '${local.hook_fix_selftest_repository}'",
    "assertion.job_workflow_ref.startsWith('${local.hook_fix_selftest_workflow}@')",
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "hook_fix_selftest_reader" {
  project      = google_project.env.project_id
  account_id   = "hook-fix-selftest-reader"
  display_name = "Hook-fix self-test App Reader"
  description  = "Identity renovate-config's hook-fix self-test federates into to read the self-test App's credentials"

  depends_on = [google_project_service.iam]
}

resource "google_service_account_iam_member" "hook_fix_selftest_reader" {
  for_each = toset([
    "roles/iam.workloadIdentityUser",
    "roles/iam.serviceAccountTokenCreator",
  ])

  service_account_id = google_service_account.hook_fix_selftest_reader.name
  role               = each.key
  member             = local.hook_fix_selftest_wif_principal

  depends_on = [google_iam_workload_identity_pool_provider.hook_fix_selftest]
}

# The reader holds no project IAM; these grants are its entire authority.
resource "google_secret_manager_secret_iam_member" "hook_fix_selftest_app_reader" {
  for_each = google_secret_manager_secret.hook_fix_selftest_app

  project   = each.value.project
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.hook_fix_selftest_reader.email}"
}
