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
# One token per collector, so rotating or revoking one host leaves the others
# pushing.
locals {
  # Policy and token carry one name so the Cloud Portal shows which token came
  # from which policy. truenas keeps the names it had before this became a map,
  # because changing a policy's name or a secret's ID replaces it.
  grafana_alloy_push = {
    truenas = {
      name         = "alunduil-infrastructure-alloy-push"
      display_name = "alunduil-infrastructure alloy push"
      secret_id    = "grafana-alloy-push-token"
      # Traces and profiles are absent because nothing sends them.
      scopes = ["logs:write", "metrics:write"]
    }
    nanopi-neo3 = {
      name         = "alunduil-infrastructure-alloy-push-nanopi-neo3"
      display_name = "alunduil-infrastructure alloy push (nanopi-neo3)"
      secret_id    = "grafana-alloy-push-token-nanopi-neo3"
      # The same token authenticates the box's remotecfg block to Fleet
      # Management, so the host holds a single Grafana credential.
      scopes = ["fleet-management:read", "logs:write", "metrics:write"]
    }
  }
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
  for_each = local.grafana_alloy_push

  region       = data.grafana_cloud_stack.this.region_slug
  name         = each.value.name
  display_name = each.value.display_name

  # Write-only for telemetry: alloy reads no logs or metrics back, so there is
  # no RO/RW split.
  scopes = each.value.scopes

  realm {
    type       = "stack"
    identifier = data.grafana_cloud_stack.this.id
  }
}

# No expires_at: a lapse would silently stop ingestion and nothing here renews
# one. Rotation is a bootstrap re-run, which replaces the token and the Secret
# Manager version together.
resource "grafana_cloud_access_policy_token" "alloy_push" {
  for_each = local.grafana_alloy_push

  region           = data.grafana_cloud_stack.this.region_slug
  access_policy_id = grafana_cloud_access_policy.alloy_push[each.key].policy_id
  name             = each.value.name
}

# Secret Manager is the publication channel rather than a bootstrap output: this
# layer's state holds the token in plaintext and no deployer can read that state.
#
# No secretAccessor binding, though every other secret this layer creates grants
# one to at least one deployer. Nothing in terraform/alunduil/ resolves this
# value — pipeline contents carry the literal string sys.env("GCLOUD_RW_API_KEY")
# — so a CI binding would grant plan and apply log and metric write for nothing.
# An operator delivers each token to its host from
# docs/how-to/configure-alloy-push-credential.md.
resource "google_secret_manager_secret" "grafana_alloy_push_token" {
  for_each = local.grafana_alloy_push

  project   = google_project.env.project_id
  secret_id = each.value.secret_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "grafana_alloy_push_token" {
  for_each = local.grafana_alloy_push

  secret      = google_secret_manager_secret.grafana_alloy_push_token[each.key].id
  secret_data = grafana_cloud_access_policy_token.alloy_push[each.key].token
}
