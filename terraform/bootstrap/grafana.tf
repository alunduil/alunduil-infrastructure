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

# Unlike the Cloudflare deployer tokens, these two secrets have no RO/RW split:
# Grafana provisioning has no read-only-yet-plannable role, and the Git Sync App
# key is a single credential shared by plan and apply. Both deployer SAs
# therefore read both secrets. The per-secret accessor isolation from
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

resource "google_secret_manager_secret" "grafana_git_sync_app_private_key" {
  project   = google_project.env.project_id
  secret_id = "grafana-git-sync-app-private-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "grafana_git_sync_app_private_key" {
  secret      = google_secret_manager_secret.grafana_git_sync_app_private_key.id
  secret_data = var.grafana_git_sync_app_private_key
}

resource "google_secret_manager_secret_iam_member" "grafana_git_sync_app_private_key_ro" {
  project   = google_secret_manager_secret.grafana_git_sync_app_private_key.project
  secret_id = google_secret_manager_secret.grafana_git_sync_app_private_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}

resource "google_secret_manager_secret_iam_member" "grafana_git_sync_app_private_key_rw" {
  project   = google_secret_manager_secret.grafana_git_sync_app_private_key.project
  secret_id = google_secret_manager_secret.grafana_git_sync_app_private_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}
