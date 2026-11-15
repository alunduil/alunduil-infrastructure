# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The hook-fix self-test App's credentials, read at runtime by renovate-config's
# hook-fix-selftest.yml.

locals {
  hook_fix_selftest_app_secrets = toset([
    "hook-fix-selftest-app-id",
    "hook-fix-selftest-app-private-key",
  ])
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

# Any ref, so a pull request's own copy of the self-test can authenticate.
module "hook_fix_selftest_reader" {
  source = "../modules/workflow_secret_reader"

  project_id = google_project.env.project_id

  pool = {
    id                   = "hook-fix-selftest"
    display_name         = "Hook fix self-test"
    description          = "Workload Identity Pool for renovate-config's hook-fix self-test"
    provider_description = "OIDC provider for renovate-config's hook-fix self-test"
  }

  caller = {
    workflow            = "alunduil/renovate-config/.github/workflows/hook-fix-selftest.yml"
    principal_attribute = "repository"
  }

  service_account = {
    account_id   = "hook-fix-selftest-reader"
    display_name = "Hook-fix self-test App Reader"
    description  = "Identity renovate-config's hook-fix self-test federates into to read the self-test App's credentials"
  }

  secret_ids = [for secret in google_secret_manager_secret.hook_fix_selftest_app : secret.secret_id]

  depends_on = [google_project_service.sts, google_project_service.iam]
}
