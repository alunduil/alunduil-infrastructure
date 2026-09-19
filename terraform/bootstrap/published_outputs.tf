# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# terraform/alunduil/ needs a few non-sensitive bootstrap values (project ID,
# Grafana stack coordinates), but the CI deployer SAs hold no IAM on this
# layer's own state bucket — that isolation is what closes #80, since the
# bootstrap state also holds plaintext deployer tokens. Republish only the
# non-secret values as a JSON object in the shared alunduil-tfstate bucket,
# which the deployer SAs already read, so terraform/alunduil/ can consume them
# without gaining read on the bootstrap state.
resource "google_storage_bucket_object" "published_outputs" {
  bucket       = data.google_storage_bucket.state.name
  name         = "bootstrap-outputs.json"
  content_type = "application/json"
  # Grafana Cloud issues a separate user ID per product, so none of the three
  # *_user_id values below is grafana_stack_id and none is interchangeable with
  # another. Each is the username half of that product's basic auth.
  #
  # The logs and metrics coordinates are here so Fleet Management pipeline
  # contents in terraform/alunduil/ can interpolate their endpoints instead of
  # carrying hardcoded cluster names that go stale if the stack moves. logs_url
  # is a base URL — alloy's loki.write wants /loki/api/v1/push appended — while
  # prometheus_remote_write_endpoint is already the full push path.
  content = jsonencode({
    project_id                               = google_project.env.project_id
    grafana_stack_url                        = data.grafana_cloud_stack.this.url
    grafana_stack_id                         = data.grafana_cloud_stack.this.id
    grafana_gcp_reader_email                 = google_service_account.grafana_gcp_reader.email
    grafana_fleet_management_url             = data.grafana_cloud_stack.this.fleet_management_url
    grafana_fleet_management_user_id         = data.grafana_cloud_stack.this.fleet_management_user_id
    grafana_logs_url                         = data.grafana_cloud_stack.this.logs_url
    grafana_logs_user_id                     = data.grafana_cloud_stack.this.logs_user_id
    grafana_prometheus_remote_write_endpoint = data.grafana_cloud_stack.this.prometheus_remote_write_endpoint
    grafana_prometheus_user_id               = data.grafana_cloud_stack.this.prometheus_user_id
  })
}
