# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Fleet Management serves pipeline contents to a collector, which evaluates them
# itself, so a pipeline can't carry the credential it pushes with: the collector
# has to already hold it as GCLOUD_RW_API_KEY. Grafana's generated
# self_monitoring_* pipelines have that name hardcoded, which makes it the
# collector's interface rather than a choice this layer makes.
#
# This lives in bootstrap because a Cloud access policy needs Cloud API auth
# carrying accesspolicies:write. terraform/alunduil/ authenticates to the stack,
# and granting it policy-write would let a pull request rewrite any policy here,
# including the ones gating its own plan.
resource "grafana_cloud_access_policy" "alloy_push" {
  region       = data.grafana_cloud_stack.this.region_slug
  name         = "alunduil-infrastructure-alloy-push"
  display_name = "alunduil-infrastructure alloy push"

  # Write-only: alloy ships logs and metrics and reads neither back. Unlike the
  # Fleet Management pair there is no RO/RW split, because there is no read side
  # to separate. Traces and profiles are absent because nothing sends them;
  # adding one later is a scope edit.
  scopes = ["logs:write", "metrics:write"]

  realm {
    type       = "stack"
    identifier = data.grafana_cloud_stack.this.id
  }
}

# No expires_at, for the reason grafana_fleet_management.tf gives: a lapse would
# silently stop ingestion and nothing here renews one. Rotation is a bootstrap
# re-run, which replaces the token and the Secret Manager version together.
resource "grafana_cloud_access_policy_token" "alloy_push" {
  region           = data.grafana_cloud_stack.this.region_slug
  access_policy_id = grafana_cloud_access_policy.alloy_push.policy_id
  name             = "alunduil-infrastructure-alloy-push"
}

# Secret Manager is the publication channel rather than a bootstrap output: this
# layer's state holds the token in plaintext, and the deployer SAs hold no IAM on
# its bucket.
resource "google_secret_manager_secret" "grafana_alloy_push_token" {
  project   = google_project.env.project_id
  secret_id = "grafana-alloy-push-token"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "grafana_alloy_push_token" {
  secret      = google_secret_manager_secret.grafana_alloy_push_token.id
  secret_data = grafana_cloud_access_policy_token.alloy_push.token
}

# Every other secret this layer creates grants secretAccessor to one or both
# deployers, so the absence here is the notable part. The consumer is the alloy
# container on A-01, a P-4 an operator configures by hand from
# docs/how-to/configure-alloy-push-credential.md. Nothing in terraform/alunduil/
# resolves this value — pipeline contents carry the literal string
# sys.env("GCLOUD_RW_API_KEY") — so a CI binding would grant plan and apply log
# and metric write for nothing.
