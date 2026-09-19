# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Read the existing stack so the alunduil layer can consume its App Platform
# coordinates (url + numeric id) through remote state, the way it already reads
# project_id.
data "grafana_cloud_stack" "this" {
  slug = var.grafana_stack_slug
}

# Admin because the alunduil layer needs actions no lesser basic role grants:
# provisioning.connections:read and :write for the Git Sync connection, and
# datasources:write for the Cloud Monitoring data source.
# Fine-grained RBAC roles would grant just those, but a stack service account
# takes a basic role only and custom roles need a stack plan with RBAC. Revisit
# if this stack moves to one. See the single-secret note below.
resource "grafana_cloud_stack_service_account" "provisioner" {
  stack_slug  = data.grafana_cloud_stack.this.slug
  name        = "alunduil-infrastructure-provisioner"
  role        = "Admin"
  is_disabled = false
}

resource "grafana_cloud_stack_service_account_token" "provisioner" {
  stack_slug         = data.grafana_cloud_stack.this.slug
  name               = "alunduil-infrastructure-provisioner"
  service_account_id = grafana_cloud_stack_service_account.provisioner.id
}

# Unlike the Cloudflare deployer tokens, these secrets have no RO/RW split. The
# provisioner role above has no read-only variant, and the Git Sync App
# credentials are one identity: the private key is a write-only secure value the
# connection resource sends, which plan needs to avoid a spurious diff. Both
# deployer SAs therefore read every one of them. The per-secret accessor
# isolation from cloudflare_tokens.tf still applies, so no value reaches
# bucket-readable state. For personal infra whose PRs are owner-originated this
# shared access is acceptable; revisit if plan ever runs from less-trusted refs.
resource "google_secret_manager_secret" "grafana_provisioner_token" {
  project   = google_project.env.project_id
  secret_id = "grafana-provisioner-token"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "grafana_provisioner_token" {
  secret      = google_secret_manager_secret.grafana_provisioner_token.id
  secret_data = grafana_cloud_stack_service_account_token.provisioner.key
}

resource "google_secret_manager_secret_iam_member" "grafana_provisioner_token_ro" {
  project   = google_secret_manager_secret.grafana_provisioner_token.project
  secret_id = google_secret_manager_secret.grafana_provisioner_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

resource "google_secret_manager_secret_iam_member" "grafana_provisioner_token_rw" {
  project   = google_secret_manager_secret.grafana_provisioner_token.project
  secret_id = google_secret_manager_secret.grafana_provisioner_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}

# The App ID and installation ID are not secret. They live here because none of
# the three exists until the App is registered by hand, which leaves
# terraform/alunduil/ nothing to read until then.
locals {
  grafana_git_sync_app_secrets = toset([
    "grafana-git-sync-app-id",
    "grafana-git-sync-app-installation-id",
    "grafana-git-sync-app-private-key",
  ])
}

# Empty shells. scripts/configure-git-sync-secrets.sh adds the versions after
# this layer applies: a version Terraform created would hold the private key in
# this layer's state, and would demand the PEM, which GitHub shows once, on
# every later run of the layer.
resource "google_secret_manager_secret" "grafana_git_sync_app" {
  for_each = local.grafana_git_sync_app_secrets

  project   = google_project.env.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

moved {
  from = google_secret_manager_secret.grafana_git_sync_app_private_key
  to   = google_secret_manager_secret.grafana_git_sync_app["grafana-git-sync-app-private-key"]
}

# configure-git-sync-secrets.sh owns the live version from here.
removed {
  from = google_secret_manager_secret_version.grafana_git_sync_app_private_key

  lifecycle {
    destroy = false
  }
}

resource "google_secret_manager_secret_iam_member" "grafana_git_sync_app_ro" {
  for_each = google_secret_manager_secret.grafana_git_sync_app

  project   = each.value.project
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

moved {
  from = google_secret_manager_secret_iam_member.grafana_git_sync_app_private_key_ro
  to   = google_secret_manager_secret_iam_member.grafana_git_sync_app_ro["grafana-git-sync-app-private-key"]
}

resource "google_secret_manager_secret_iam_member" "grafana_git_sync_app_rw" {
  for_each = google_secret_manager_secret.grafana_git_sync_app

  project   = each.value.project
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}

moved {
  from = google_secret_manager_secret_iam_member.grafana_git_sync_app_private_key_rw
  to   = google_secret_manager_secret_iam_member.grafana_git_sync_app_rw["grafana-git-sync-app-private-key"]
}

# Fleet Management answers on its own regional host, not the stack server —
# `/apis/fleet.ext.grafana.app/...` against https://<slug>.grafana.net is a 404 —
# and it takes basic auth rather than a stack service-account token. The
# provisioner token above reaches none of it, so the alunduil layer needs a
# second Grafana credential: a Cloud access policy on this stack's realm.
#
# Split by role for the reason tailscale.tf gives: plan runs on pull requests,
# which supply the workflow that runs, so the credential plan can reach grants
# no write. The stack Admin role had no read-only variant; access-policy scopes
# do. Driving policy, token, secret, and binding from one map keeps each role's
# scopes paired with the one service account that can read them.
locals {
  grafana_fleet_management_deployers = {
    ro = {
      scopes = ["fleet-management:read"]
      email  = google_service_account.github_deployer_ro.email
    }
    rw = {
      scopes = ["fleet-management:read", "fleet-management:write"]
      email  = google_service_account.github_deployer_rw.email
    }
  }
}

resource "grafana_cloud_access_policy" "fleet_management" {
  for_each = local.grafana_fleet_management_deployers

  region       = data.grafana_cloud_stack.this.region_slug
  name         = "alunduil-infrastructure-fleet-management-${each.key}"
  display_name = "alunduil-infrastructure Fleet Management (${upper(each.key)})"

  scopes = each.value.scopes

  realm {
    type       = "stack"
    identifier = data.grafana_cloud_stack.this.id
  }
}

# No expires_at: the token would strand plan and apply the day it lapsed, and
# nothing here would renew it. Rotation means re-running bootstrap, which
# replaces the token and the Secret Manager version together.
resource "grafana_cloud_access_policy_token" "fleet_management" {
  for_each = local.grafana_fleet_management_deployers

  region           = data.grafana_cloud_stack.this.region_slug
  access_policy_id = grafana_cloud_access_policy.fleet_management[each.key].policy_id
  name             = "alunduil-infrastructure-fleet-management-${each.key}"
}

resource "google_secret_manager_secret" "grafana_fleet_management_token" {
  for_each = local.grafana_fleet_management_deployers

  project   = google_project.env.project_id
  secret_id = "grafana-fleet-management-token-${each.key}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "grafana_fleet_management_token" {
  for_each = local.grafana_fleet_management_deployers

  secret      = google_secret_manager_secret.grafana_fleet_management_token[each.key].id
  secret_data = grafana_cloud_access_policy_token.fleet_management[each.key].token
}

resource "google_secret_manager_secret_iam_member" "grafana_fleet_management_token" {
  for_each = local.grafana_fleet_management_deployers

  project   = google_secret_manager_secret.grafana_fleet_management_token[each.key].project
  secret_id = google_secret_manager_secret.grafana_fleet_management_token[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.email}"
}
