# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The hook-fix App's credentials, read at runtime by renovate-config's
# fix-renovate-hooks.yml.

locals {
  hook_fix_app_secrets = toset([
    "hook-fix-app-id",
    "hook-fix-app-private-key",
  ])
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
# only a prefix can match. That admits every ref of the file in renovate-config,
# branches included. Callers are other repositories, hence the owner principal.
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
    workflow            = "alunduil/renovate-config/.github/workflows/fix-renovate-hooks.yml"
    principal_attribute = "repository_owner"
  }

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
