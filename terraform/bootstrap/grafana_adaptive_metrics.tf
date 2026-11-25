# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The Adaptive Metrics API answers on the stack's metrics host with basic auth,
# so the provisioner token in grafana.tf can't reach it. Split by role for the
# reason tailscale.tf gives.
locals {
  # Covers the recommendations configuration alone. Rules and exemptions have
  # scopes of their own.
  grafana_adaptive_metrics_scopes = {
    ro = ["adaptive-metrics-config:read"]
    rw = ["adaptive-metrics-config:read", "adaptive-metrics-config:write"]
  }
}

resource "grafana_cloud_access_policy" "adaptive_metrics" {
  for_each = local.grafana_adaptive_metrics_scopes

  region       = data.grafana_cloud_stack.this.region_slug
  name         = "alunduil-infrastructure-adaptive-metrics-${each.key}"
  display_name = "alunduil-infrastructure Adaptive Metrics (${upper(each.key)})"

  scopes = each.value

  realm {
    type       = "stack"
    identifier = data.grafana_cloud_stack.this.id
  }
}

# No expires_at, for the reason grafana_fleet_management.tf gives.
resource "grafana_cloud_access_policy_token" "adaptive_metrics" {
  for_each = local.grafana_adaptive_metrics_scopes

  region           = data.grafana_cloud_stack.this.region_slug
  access_policy_id = grafana_cloud_access_policy.adaptive_metrics[each.key].policy_id
  name             = grafana_cloud_access_policy.adaptive_metrics[each.key].name
}

resource "google_secret_manager_secret" "grafana_adaptive_metrics_token" {
  for_each = local.grafana_adaptive_metrics_scopes

  project   = google_project.env.project_id
  secret_id = "grafana-adaptive-metrics-token-${each.key}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "grafana_adaptive_metrics_token" {
  for_each = local.grafana_adaptive_metrics_scopes

  secret      = google_secret_manager_secret.grafana_adaptive_metrics_token[each.key].id
  secret_data = grafana_cloud_access_policy_token.adaptive_metrics[each.key].token
}

resource "google_secret_manager_secret_iam_member" "grafana_adaptive_metrics_token" {
  for_each = local.grafana_adaptive_metrics_scopes

  project   = google_secret_manager_secret.grafana_adaptive_metrics_token[each.key].project
  secret_id = google_secret_manager_secret.grafana_adaptive_metrics_token[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.deployers[each.key]}"
}
