# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

locals {
  # Both plugins read the @grafana/google-sdk credential shape, so one
  # definition serves both data sources.
  #
  # The private key is absent by design: this layer's state is bucket-readable,
  # so scripts/set-grafana-gcp-credentials.sh sets it as the operator. Grafana
  # preserves secure fields omitted from an update, which is what lets the
  # resources below ignore_changes it and still apply cleanly.
  grafana_gcp_reader_auth = jsonencode({
    authenticationType = "jwt"
    defaultProject     = local.bootstrap.project_id
    clientEmail        = local.bootstrap.grafana_gcp_reader_email
    tokenUri           = "https://oauth2.googleapis.com/token"
  })
}

# Grafana Cloud queries GCP live at dashboard time instead of ingesting into
# Loki or Prometheus. The audit-log volume here is a trickle, too small to earn
# a Pub/Sub topic and an always-on collector.
resource "grafana_data_source" "gcp_cloud_monitoring" {
  type = "stackdriver"
  name = "GCP Cloud Monitoring"
  uid  = "gcp-cloud-monitoring"

  json_data_encoded = local.grafana_gcp_reader_auth

  lifecycle {
    ignore_changes = [secure_json_data_encoded]
  }
}

# Cloud Monitoring counts audit entries but discards their content, so reading a
# log line means querying Cloud Logging directly. The plugin asks for
# logging.viewer and logging.viewAccessor, which grafana-gcp-reader already
# holds.
#
# terraform/bootstrap/ installs the plugin this configures.
resource "grafana_data_source" "gcp_cloud_logging" {
  type = "googlecloud-logging-datasource"
  name = "GCP Cloud Logging"
  uid  = "gcp-cloud-logging"

  json_data_encoded = local.grafana_gcp_reader_auth

  lifecycle {
    ignore_changes = [secure_json_data_encoded]
  }
}

locals {
  # A logName is URL-escaped, so the / in cloudaudit.googleapis.com/data_access
  # arrives as %2F.
  data_access_log = "projects/${local.bootstrap.project_id}/logs/cloudaudit.googleapis.com%2Fdata_access"
}

# Grafana reads GCP through Cloud Monitoring, so the audit trail has to become a
# metric before it can appear there. It arrives as metric type
# logging.googleapis.com/user/audit-data-access.
resource "google_logging_metric" "audit_data_access" {
  name   = "audit-data-access"
  filter = "logName=\"${local.data_access_log}\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }

  depends_on = [google_project_service.kept["logging.googleapis.com"]]
}
