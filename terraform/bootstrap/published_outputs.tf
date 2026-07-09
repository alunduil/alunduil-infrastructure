# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# terraform/alunduil/ needs a few non-sensitive bootstrap values (project ID,
# Grafana stack coordinates, Git Sync App identifiers), but the CI deployer SAs
# hold no IAM on this layer's own state bucket — that isolation is what closes
# #80, since the bootstrap state also holds plaintext deployer tokens. Republish
# only the non-secret values as a JSON object in the shared alunduil-tfstate
# bucket, which the deployer SAs already read, so terraform/alunduil/ can consume
# them without gaining read on the bootstrap state.
resource "google_storage_bucket_object" "published_outputs" {
  bucket       = data.google_storage_bucket.state.name
  name         = "bootstrap-outputs.json"
  content_type = "application/json"
  content = jsonencode({
    project_id                           = google_project.env.project_id
    grafana_stack_url                    = data.grafana_cloud_stack.this.url
    grafana_stack_id                     = data.grafana_cloud_stack.this.id
    grafana_git_sync_app_id              = var.grafana_git_sync_app_id
    grafana_git_sync_app_installation_id = var.grafana_git_sync_app_installation_id
  })
}
