# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Fleet Management serves pipeline contents to a collector, which evaluates them
# itself, so a pipeline can't carry the credential it pushes with: the collector
# has to already hold it as GCLOUD_RW_API_KEY. Grafana's generated
# self_monitoring_* pipelines have that name hardcoded.
#
# This lives in bootstrap because a Cloud access policy needs Cloud API auth
# carrying accesspolicies:write. terraform/alunduil/ authenticates to the stack,
# and granting it policy-write would let a pull request rewrite any policy here,
# including the ones gating its own plan.
#
# Rotating or revoking one collector's token leaves the others pushing.
locals {
  # Policy and token carry one name so the Cloud Portal shows which token came
  # from which policy.
  grafana_alloy_push_name = "alunduil-infrastructure-alloy-push"

  # Traces and profiles are absent because nothing sends them.
  grafana_alloy_push_scopes = ["logs:write", "metrics:write"]

  # A Fleet Management box's remotecfg login and its pushes share one token, so
  # each box holds one Grafana credential.
  grafana_alloy_fleet_collectors = toset(["truenas", "nanopi-neo3"])

  grafana_alloy_collectors = setunion(local.grafana_alloy_fleet_collectors, ["homeassistant"])

  grafana_alloy_push_scopes_by_collector = {
    for collector in local.grafana_alloy_collectors : collector => concat(
      contains(local.grafana_alloy_fleet_collectors, collector) ? ["fleet-management:read"] : [],
      local.grafana_alloy_push_scopes,
    )
  }

  # Renaming a policy or a secret replaces it, and the collector's token with
  # it, so truenas's names carry no suffix.
  grafana_alloy_collector_suffixes = merge(
    { for collector in local.grafana_alloy_collectors : collector => "-${collector}" },
    { truenas = "" },
  )
}

moved {
  from = grafana_cloud_access_policy.alloy_push
  to   = grafana_cloud_access_policy.alloy_push["truenas"]
}

moved {
  from = grafana_cloud_access_policy_token.alloy_push
  to   = grafana_cloud_access_policy_token.alloy_push["truenas"]
}

moved {
  from = google_secret_manager_secret.grafana_alloy_push_token
  to   = google_secret_manager_secret.grafana_alloy_push_token["truenas"]
}

moved {
  from = google_secret_manager_secret_version.grafana_alloy_push_token
  to   = google_secret_manager_secret_version.grafana_alloy_push_token["truenas"]
}

resource "grafana_cloud_access_policy" "alloy_push" {
  for_each = local.grafana_alloy_collectors

  region       = data.grafana_cloud_stack.this.region_slug
  name         = "${local.grafana_alloy_push_name}${local.grafana_alloy_collector_suffixes[each.key]}"
  display_name = "alunduil-infrastructure alloy push${local.grafana_alloy_collector_suffixes[each.key] == "" ? "" : " (${each.key})"}"

  scopes = local.grafana_alloy_push_scopes_by_collector[each.key]

  realm {
    type       = "stack"
    identifier = data.grafana_cloud_stack.this.id
  }
}

# No expires_at: a lapse would silently stop ingestion and nothing here renews
# one. Rotation is a bootstrap re-run, which replaces the token and the Secret
# Manager version together.
resource "grafana_cloud_access_policy_token" "alloy_push" {
  for_each = local.grafana_alloy_collectors

  region           = data.grafana_cloud_stack.this.region_slug
  access_policy_id = grafana_cloud_access_policy.alloy_push[each.key].policy_id
  name             = grafana_cloud_access_policy.alloy_push[each.key].name
}

# Secret Manager is the publication channel rather than a bootstrap output: this
# layer's state holds the token in plaintext and no deployer can read that state.
#
# No secretAccessor binding, though every other secret this layer creates grants
# one to at least one deployer. Nothing in terraform/alunduil/ resolves this
# value — pipeline contents carry the literal string sys.env("GCLOUD_RW_API_KEY")
# — so a CI binding would grant plan and apply log and metric write for nothing.
# An operator delivers each token to its collector from
# docs/how-to/configure-alloy-push-credential.md.
resource "google_secret_manager_secret" "grafana_alloy_push_token" {
  for_each = local.grafana_alloy_collectors

  project   = google_project.env.project_id
  secret_id = "grafana-alloy-push-token${local.grafana_alloy_collector_suffixes[each.key]}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "grafana_alloy_push_token" {
  for_each = local.grafana_alloy_collectors

  secret      = google_secret_manager_secret.grafana_alloy_push_token[each.key].id
  secret_data = grafana_cloud_access_policy_token.alloy_push[each.key].token
}
