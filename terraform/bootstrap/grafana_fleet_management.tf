# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Fleet Management answers on its own regional host, not the stack server, and
# takes basic auth rather than a stack service-account token. The provisioner
# token in grafana.tf reaches none of it, so the alunduil layer needs a second
# Grafana credential: a Cloud access policy on this stack's realm.
#
# Split by role for the reason tailscale.tf gives. The stack Admin role has no
# read-only variant; access-policy scopes do.
locals {
  # Policy and token carry one name so the Cloud Portal shows which token came
  # from which policy.
  grafana_fleet_management_name = "alunduil-infrastructure-fleet-management"

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
  name         = "${local.grafana_fleet_management_name}-${each.key}"
  display_name = "alunduil-infrastructure Fleet Management (${upper(each.key)})"

  scopes = each.value.scopes

  realm {
    type       = "stack"
    identifier = data.grafana_cloud_stack.this.id
  }
}

# No expires_at: a lapse would strand plan and apply, and nothing here renews
# one. Rotation is a bootstrap re-run, which replaces the token and the Secret
# Manager version together.
resource "grafana_cloud_access_policy_token" "fleet_management" {
  for_each = local.grafana_fleet_management_deployers

  region           = data.grafana_cloud_stack.this.region_slug
  access_policy_id = grafana_cloud_access_policy.fleet_management[each.key].policy_id
  name             = "${local.grafana_fleet_management_name}-${each.key}"
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
