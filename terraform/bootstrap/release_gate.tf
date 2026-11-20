# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The release gate's credentials, read only by alunduil/release-gate's deploy
# workflow on main. Its Worker approves publish deployments, so whoever reads
# these can approve an off-branch run.

# The provider's condition and the reader's binding have to name the same
# workflow, and a disagreement between them fails the exchange silently.
locals {
  release_gate_repository          = "alunduil/release-gate"
  release_gate_deploy_workflow_ref = "${local.release_gate_repository}/.github/workflows/deploy.yml@refs/heads/main"
  release_gate_wif_principal       = "${local.wif_pool_prefix}/${google_iam_workload_identity_pool.release_gate.workload_identity_pool_id}/attribute.repository/${local.release_gate_repository}"
}

# Empty shell. scripts/configure-release-gate-secrets.sh adds the version after
# this layer applies, so the private key never reaches this layer's state.
resource "google_secret_manager_secret" "release_gate_app_private_key" {
  project   = google_project.env.project_id
  secret_id = "release-gate-app-private-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# GitHub only stores this secret, so the operator copies it into the App's
# webhook settings.
resource "random_password" "release_gate_webhook_secret" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret" "release_gate_webhook_secret" {
  project   = google_project.env.project_id
  secret_id = "release-gate-webhook-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "release_gate_webhook_secret" {
  secret      = google_secret_manager_secret.release_gate_webhook_secret.id
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

resource "google_secret_manager_secret" "cloudflare_api_token_release_gate_deploy" {
  project   = google_project.env.project_id
  secret_id = "cloudflare-api-token-release-gate-deploy"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "cloudflare_api_token_release_gate_deploy" {
  secret      = google_secret_manager_secret.cloudflare_api_token_release_gate_deploy.id
  secret_data = cloudflare_api_token.release_gate_deploy.value
}

# Its own pool. principalSet paths are pool-scoped, so no `github` binding can
# match a token from this repository.
resource "google_iam_workload_identity_pool" "release_gate" {
  project                   = google_project.env.project_id
  workload_identity_pool_id = "release-gate"
  display_name              = "Release gate"
  description               = "Workload Identity Pool for the release gate's deploy workflow"
  disabled                  = false

  depends_on = [google_project_service.sts]
}

resource "google_iam_workload_identity_pool_provider" "release_gate" {
  project                            = google_project.env.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.release_gate.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub"
  description                        = "OIDC provider for the release gate's deploy workflow"
  disabled                           = false

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # Pinned to the workflow and branch, so another workflow on main, or this one
  # on a pull request branch, can't read the App's key. Renaming or moving
  # deploy.yml revokes access.
  attribute_condition = "assertion.job_workflow_ref == '${local.release_gate_deploy_workflow_ref}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "release_gate_reader" {
  project      = google_project.env.project_id
  account_id   = "release-gate-reader"
  display_name = "Release Gate Reader"
  description  = "Identity the release gate's deploy workflow federates into to read the gate's credentials"

  depends_on = [google_project_service.iam]
}

resource "google_service_account_iam_member" "release_gate_reader" {
  for_each = toset([
    "roles/iam.workloadIdentityUser",
    "roles/iam.serviceAccountTokenCreator",
  ])

  service_account_id = google_service_account.release_gate_reader.name
  role               = each.key
  member             = local.release_gate_wif_principal

  depends_on = [google_iam_workload_identity_pool_provider.release_gate]
}

# The reader holds no project IAM; these grants are its entire authority.
resource "google_secret_manager_secret_iam_member" "release_gate_reader" {
  for_each = {
    app_private_key = google_secret_manager_secret.release_gate_app_private_key
    webhook_secret  = google_secret_manager_secret.release_gate_webhook_secret
    deploy_token    = google_secret_manager_secret.cloudflare_api_token_release_gate_deploy
  }

  project   = each.value.project
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.release_gate_reader.email}"
}
