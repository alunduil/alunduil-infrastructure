# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Read the existing stack so the alunduil layer can consume its App Platform
# coordinates (url + numeric id) through remote state, the way it already reads
# project_id.
data "grafana_cloud_stack" "this" {
  slug = var.grafana_stack_slug
}

# Service account the alunduil layer's Grafana provider authenticates as to
# manage the Git Sync repository. Admin because Git Sync provisioning exposes no
# read-only role that can still plan the repository resource — see the
# single-secret note below.
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

# Unlike the Cloudflare deployer tokens, these secrets have no RO/RW split:
# Grafana provisioning has no read-only-yet-plannable role, and the Git Sync App
# credentials are a single identity shared by plan and apply. Both deployer SAs
# therefore read every one of them. The per-secret accessor isolation from
# cloudflare_tokens.tf still applies — the values never live in bucket-readable
# state, only behind secretAccessor IAM. For personal infra whose PRs are
# owner-originated this shared access is acceptable; revisit if plan ever runs
# from less-trusted refs.
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

# The App ID and installation ID are not secret. They share the private key's
# store because none of the three exists until the App is registered by hand,
# which leaves terraform/alunduil/ nothing to read until then — one store for
# the whole credential beats splitting it across two mechanisms.
locals {
  grafana_git_sync_app_secrets = toset([
    "grafana-git-sync-app-id",
    "grafana-git-sync-app-installation-id",
    "grafana-git-sync-app-private-key",
  ])
}

# Empty shells. scripts/configure-git-sync-secrets.sh adds the versions once
# this layer has applied. A version Terraform created would hold the private key
# in this layer's state, and would make every later bootstrap run demand a PEM
# that GitHub shows only once — so an unrelated edit here would cost a rotation
# of a working credential.
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

# Forget the version without deleting it: the live PEM stays readable, and
# configure-git-sync-secrets.sh then finds a populated secret and leaves it be.
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
