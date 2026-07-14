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
# reads/writes and Secret Manager access). The Cloud Logging query language has
# no Grafana alerting support, so audit alerting rides this counter through the
# Cloud Monitoring data source (metric type logging.googleapis.com/user/<name>)
# instead of alerting on log lines directly.
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

# Folder holding the alert rules that query GCP. Kept separate from the Git
# Sync dashboard folders so a dashboard sync can't disturb alerting.
resource "grafana_folder" "gcp_observability" {
  title = "GCP Observability"
  uid   = "gcp-observability"
}

# Audit alert, fully declarative: it references the data source by UID, so the
# out-of-band credential (scripts/set-grafana-gcp-credentials.sh) is the only
# manual step. The query aligns the DELTA counter per period (A), reduces to the
# last value (B), and fires when it exceeds the threshold (C). Threshold 0 fires
# on any Data Access event; raise it in the rule to alert only on bursts.
resource "grafana_rule_group" "audit_data_access" {
  name             = "GCP audit"
  folder_uid       = grafana_folder.gcp_observability.uid
  interval_seconds = 60

  rule {
    name           = "Data Access audit events"
    condition      = "C"
    for            = "0s"
    no_data_state  = "OK"
    exec_err_state = "Error"
    labels         = { severity = "warning" }

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.gcp_cloud_monitoring.uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        refId     = "A"
        queryType = "timeSeriesList"
        datasource = {
          type = "stackdriver"
          uid  = grafana_data_source.gcp_cloud_monitoring.uid
        }
        timeSeriesList = {
          projectName        = local.bootstrap.project_id
          filters            = ["metric.type", "=", "logging.googleapis.com/user/${google_logging_metric.audit_data_access.name}"]
          perSeriesAligner   = "ALIGN_DELTA"
          crossSeriesReducer = "REDUCE_SUM"
          alignmentPeriod    = "cloud-monitoring-auto"
        }
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "A"
        reducer    = "last"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "B"
        conditions = [{ evaluator = { type = "gt", params = [0] } }]
      })
    }
  }
}
