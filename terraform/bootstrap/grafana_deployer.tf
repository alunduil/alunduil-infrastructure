# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Fleet Management and Adaptive Metrics answer on their own hosts, not the stack
# server, and take basic auth rather than a stack service-account token. The
# provisioner token in grafana.tf reaches neither, so the alunduil layer needs a
# second Grafana credential: a Cloud access policy on this stack's realm. One
# credential covers both products because the same deployer holds it.
#
# Split by role for the reason tailscale.tf gives. The stack Admin role has no
# read-only variant; access-policy scopes do.
locals {
  # Policy and token carry one name so the Cloud Portal shows which token came
  # from which policy. Renaming either, or the secret, replaces a live
  # credential.
  grafana_deployer_name = "alunduil-infrastructure-deployer"

  grafana_deployer_scopes = {
    ro = ["adaptive-metrics-config:read", "fleet-management:read"]
    rw = [
      "adaptive-metrics-config:read",
      "adaptive-metrics-config:write",
      "fleet-management:read",
      "fleet-management:write",
    ]
  }
}

resource "grafana_cloud_access_policy" "deployer" {
  for_each = local.grafana_deployer_scopes

  region       = data.grafana_cloud_stack.this.region_slug
  name         = "${local.grafana_deployer_name}-${each.key}"
  display_name = "alunduil-infrastructure deployer (${upper(each.key)})"

  scopes = each.value

  realm {
    type       = "stack"
    identifier = data.grafana_cloud_stack.this.id
  }
}

# No expires_at: a lapse would strand plan and apply, and nothing here renews
# one. Rotation is a bootstrap re-run, which replaces the token and the Secret
# Manager version together.
resource "grafana_cloud_access_policy_token" "deployer" {
  for_each = local.grafana_deployer_scopes

  region           = data.grafana_cloud_stack.this.region_slug
  access_policy_id = grafana_cloud_access_policy.deployer[each.key].policy_id
  name             = "${local.grafana_deployer_name}-${each.key}"
}

resource "google_secret_manager_secret" "grafana_deployer_token" {
  for_each = local.grafana_deployer_scopes

  project   = google_project.env.project_id
  secret_id = "grafana-deployer-token-${each.key}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "grafana_deployer_token" {
  for_each = local.grafana_deployer_scopes

  secret      = google_secret_manager_secret.grafana_deployer_token[each.key].id
  secret_data = grafana_cloud_access_policy_token.deployer[each.key].token
}

resource "google_secret_manager_secret_iam_member" "grafana_deployer_token" {
  for_each = local.grafana_deployer_scopes

  project   = google_secret_manager_secret.grafana_deployer_token[each.key].project
  secret_id = google_secret_manager_secret.grafana_deployer_token[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.deployers[each.key]}"
}
