# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The hook-fix App's credentials, read at runtime by renovate-config's
# fix-renovate-hooks.yml.

locals {
  hook_fix_app_secrets = toset([
    "hook-fix-app-id",
    "hook-fix-app-private-key",
  ])

  hook_fix_repository = "alunduil/renovate-config"

  # Matched by bot user ID, which survives a rename of the login.
  hook_fix_renovate_run = "assertion.actor_id == '29139614'"
  hook_fix_selftest_run = "(assertion.repository == '${local.hook_fix_repository}' && assertion.actor_id == '359652970')"
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

# job_workflow_ref names the called workflow at the SHA its caller pins, so
# only a prefix can match. Only Renovate changes workflows on Renovate's
# branches, so its runs call the SHA their default branch pins. Callers are
# other repositories, so the principal is their owner.
module "hook_fix_reader" {
  source = "../modules/workflow_secret_reader"

  project_id = google_project.env.project_id

  pool = {
    id                   = "hook-fix"
    display_name         = "Hook fix"
    description          = "Workload Identity Pool for the reusable hook-fix workflow"
    provider_description = "OIDC provider for the reusable hook-fix workflow"
  }

  caller = {
    workflow            = "${local.hook_fix_repository}/.github/workflows/fix-renovate-hooks.yml"
    principal_attribute = "repository_owner"
  }

  # The self-test App's runs call their branch's own copy of the workflow.
  extra_conditions = [
    "(${local.hook_fix_renovate_run} || ${local.hook_fix_selftest_run})",
    "assertion.event_name == 'pull_request'",
  ]

  service_account = {
    account_id   = "hook-fix-reader"
    display_name = "Hook-fix App Reader"
    description  = "Identity the reusable hook-fix workflow federates into to read the hook-fix App's credentials"
  }

  secret_ids = [for secret in google_secret_manager_secret.hook_fix_app : secret.secret_id]

  depends_on = [google_project_service.sts, google_project_service.iam]
}

moved {
  from = google_iam_workload_identity_pool.hook_fix
  to   = module.hook_fix_reader.google_iam_workload_identity_pool.this
}

moved {
  from = google_iam_workload_identity_pool_provider.hook_fix
  to   = module.hook_fix_reader.google_iam_workload_identity_pool_provider.this
}

moved {
  from = google_service_account.hook_fix_reader
  to   = module.hook_fix_reader.google_service_account.reader
}

moved {
  from = google_service_account_iam_member.hook_fix_reader
  to   = module.hook_fix_reader.google_service_account_iam_member.reader
}

moved {
  from = google_secret_manager_secret_iam_member.hook_fix_app_reader
  to   = module.hook_fix_reader.google_secret_manager_secret_iam_member.reader
}
