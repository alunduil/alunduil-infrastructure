# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Fleet Management and Adaptive Metrics answer on their own hosts, not the stack
# server, and take basic auth rather than a stack service-account token. The
# provisioner token in grafana.tf reaches neither, so the alunduil layer needs a
# Cloud access-policy token on this stack's realm. Each deployer holds one token
# covering both products.
#
# Split by role for the reason tailscale.tf gives. The stack Admin role has no
# read-only variant; access-policy scopes do.
locals {
  grafana_deployer_products = ["adaptive-metrics-config", "fleet-management"]

  grafana_deployer_actions = {
    ro = ["read"]
    rw = ["read", "write"]
  }
}

resource "grafana_cloud_access_policy" "deployer" {
  for_each = local.grafana_deployer_actions

  region       = data.grafana_cloud_stack.this.region_slug
  name         = "alunduil-infrastructure-deployer-${each.key}"
  display_name = "alunduil-infrastructure deployer (${upper(each.key)})"

  scopes = [for scope in setproduct(local.grafana_deployer_products, each.value) : join(":", scope)]

  realm {
    type       = "stack"
    identifier = data.grafana_cloud_stack.this.id
  }
}

# Named after its policy so the Cloud Portal shows which token came from which
# policy.
#
# No expires_at: a lapse would strand plan and apply, and nothing here renews
# one. Rotation is a bootstrap re-run, which replaces the token and the Secret
# Manager version together.
resource "grafana_cloud_access_policy_token" "deployer" {
  for_each = local.grafana_deployer_actions

  region           = data.grafana_cloud_stack.this.region_slug
  access_policy_id = grafana_cloud_access_policy.deployer[each.key].policy_id
  name             = grafana_cloud_access_policy.deployer[each.key].name
}

resource "google_secret_manager_secret" "grafana_deployer_token" {
  for_each = local.grafana_deployer_actions

  project   = google_project.env.project_id
  secret_id = "grafana-deployer-token-${each.key}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "grafana_deployer_token" {
  for_each = local.grafana_deployer_actions

  secret      = google_secret_manager_secret.grafana_deployer_token[each.key].id
  secret_data = grafana_cloud_access_policy_token.deployer[each.key].token
}

resource "google_secret_manager_secret_iam_member" "grafana_deployer_token" {
  for_each = local.grafana_deployer_actions

  project   = google_secret_manager_secret.grafana_deployer_token[each.key].project
  secret_id = google_secret_manager_secret.grafana_deployer_token[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.deployers[each.key]}"
}
