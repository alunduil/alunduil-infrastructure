# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Grafana Cloud queries GCP directly at dashboard/alert time rather than
# ingesting into Loki/Prometheus: for this personal infrastructure the audit-log
# volume is tiny and a live-query data source avoids standing up a Pub/Sub +
# collector pipeline. The read-only identity and its key live in the bootstrap
# layer (grafana_gcp_reader.tf); the key is injected here out of band by
# scripts/set-grafana-gcp-credentials.sh so it never enters this layer's
# bucket-readable state.
resource "grafana_data_source" "gcp_cloud_monitoring" {
  type = "stackdriver"
  name = "GCP Cloud Monitoring"
  uid  = "gcp-cloud-monitoring"

  json_data_encoded = jsonencode({
    authenticationType = "jwt"
    defaultProject     = local.bootstrap.project_id
    clientEmail        = local.bootstrap.grafana_gcp_reader_email
    tokenUri           = "https://oauth2.googleapis.com/token"
  })

  lifecycle {
    # privateKey is set out of band from Secret Manager, so ignore the secure
    # payload — otherwise each apply would send an empty value and wipe it.
    ignore_changes = [secure_json_data_encoded]
  }
}

# Log-based metric counting the Data Access audit events enabled in #83 (storage
# reads/writes and Secret Manager access). With no Cloud Logging data source yet
# (#228), this counter is how the audit trail surfaces in Grafana — queried as
# metric type logging.googleapis.com/user/<name> through the Cloud Monitoring
# data source. Alerting on these events is designed separately in #252.
resource "google_logging_metric" "audit_data_access" {
  name   = "audit-data-access"
  filter = "logName=\"projects/${local.bootstrap.project_id}/logs/cloudaudit.googleapis.com%2Fdata_access\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }

  depends_on = [google_project_service.logging]
}
