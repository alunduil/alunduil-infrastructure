# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Only alunduil/release-gate's deploy workflow on main reads these credentials.
# Its Worker approves publish deployments, so a reader can approve an
# off-branch run.

# Secret Manager names, not values.
locals {
  release_gate_secrets = {
    app_private_key = "release-gate-app-private-key"             # pragma: allowlist secret
    webhook_secret  = "release-gate-webhook-secret"              # pragma: allowlist secret
    deploy_token    = "cloudflare-api-token-release-gate-deploy" # pragma: allowlist secret
  }
}

# scripts/configure-release-gate-secrets.sh adds the App key's version after
# this layer applies, so the key never reaches this layer's state.
resource "google_secret_manager_secret" "release_gate" {
  for_each = local.release_gate_secrets

  project   = google_project.env.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# The operator copies this into the App's webhook settings.
resource "random_password" "release_gate_webhook_secret" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret_version" "release_gate_webhook_secret" {
  secret      = google_secret_manager_secret.release_gate["webhook_secret"].id
  secret_data = random_password.release_gate_webhook_secret.result
}

data "cloudflare_api_token_permission_groups_list" "workers_scripts_write" {
  name  = "Workers Scripts Write"
  scope = "com.cloudflare.api.account"
}

# Account-wide, because Cloudflare scopes a token to one Worker only after that
# Worker exists. The Worker serves from workers.dev, so no zone permission.
resource "cloudflare_api_token" "release_gate_deploy" {
  name = "release-gate Worker deploy"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = data.cloudflare_api_token_permission_groups_list.workers_scripts_write.result[0].id },
    ]
    resources = local.alunduil_account_resource
  }]
}

resource "google_secret_manager_secret_version" "cloudflare_api_token_release_gate_deploy" {
  secret      = google_secret_manager_secret.release_gate["deploy_token"].id
  secret_data = cloudflare_api_token.release_gate_deploy.value
}

# Pinned to the workflow and branch, so another workflow on main, or this one
# on a pull request branch, can't read these secrets. Renaming or moving
# deploy.yml revokes access.
module "release_gate_reader" {
  source = "../modules/workflow_secret_reader"

  project_id = google_project.env.project_id

  pool = {
    id                   = "release-gate"
    display_name         = "Release gate"
    description          = "Workload Identity Pool for the release gate's deploy workflow"
    provider_description = "OIDC provider for the release gate's deploy workflow"
  }

  caller = {
    workflow            = "alunduil/release-gate/.github/workflows/deploy.yml"
    ref                 = "refs/heads/main"
    principal_attribute = "repository"
  }

  service_account = {
    account_id   = "release-gate-reader"
    display_name = "Release Gate Reader"
    description  = "Identity the release gate's deploy workflow federates into to read the gate's credentials"
  }

  secret_ids = [for secret in google_secret_manager_secret.release_gate : secret.secret_id]

  depends_on = [google_project_service.sts, google_project_service.iam]
}

moved {
  from = google_iam_workload_identity_pool.release_gate
  to   = module.release_gate_reader.google_iam_workload_identity_pool.this
}

moved {
  from = google_iam_workload_identity_pool_provider.release_gate
  to   = module.release_gate_reader.google_iam_workload_identity_pool_provider.this
}

moved {
  from = google_service_account.release_gate_reader
  to   = module.release_gate_reader.google_service_account.reader
}

moved {
  from = google_service_account_iam_member.release_gate_reader
  to   = module.release_gate_reader.google_service_account_iam_member.reader
}

moved {
  from = google_secret_manager_secret_iam_member.release_gate_reader["app_private_key"]
  to   = module.release_gate_reader.google_secret_manager_secret_iam_member.reader["release-gate-app-private-key"]
}

moved {
  from = google_secret_manager_secret_iam_member.release_gate_reader["webhook_secret"]
  to   = module.release_gate_reader.google_secret_manager_secret_iam_member.reader["release-gate-webhook-secret"]
}

moved {
  from = google_secret_manager_secret_iam_member.release_gate_reader["deploy_token"]
  to   = module.release_gate_reader.google_secret_manager_secret_iam_member.reader["cloudflare-api-token-release-gate-deploy"]
}
