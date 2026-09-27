# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Grafana Cloud queries GCP live at dashboard time instead of ingesting into
# Loki or Prometheus. The audit-log volume here is a trickle, too small to earn
# a Pub/Sub topic and an always-on collector.
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
    # The private key is set from Secret Manager outside Terraform, so this
    # layer never holds it. Grafana preserves secure fields omitted from an
    # update, so applies leave the key in place.
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
# logging.googleapis.com/user/audit-data-access. The metric keeps every caller;
# the alert below decides which ones are unexpected, so dashboards can still
# slice CI traffic by principal.
resource "google_logging_metric" "audit_data_access" {
  name   = "audit-data-access"
  filter = "logName=\"${local.data_access_log}\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key        = "principal"
      value_type = "STRING"
    }

    labels {
      key        = "service"
      value_type = "STRING"
    }
  }

  label_extractors = {
    principal = "EXTRACT(protoPayload.authenticationInfo.principalEmail)"
    service   = "EXTRACT(protoPayload.serviceName)"
  }

  depends_on = [google_project_service.kept["logging.googleapis.com"]]
}

# Kept separate from the Git Sync dashboard folders so a dashboard sync can't
# disturb alerting.
resource "grafana_folder" "gcp_observability" {
  title = "GCP Observability"
  uid   = "gcp-observability"
}

locals {
  # Callers the audit alert treats as expected: the two CI deployers, and an
  # empty principal. Cloud Audit Logs skips public-object access, so an
  # anonymous caller only ever appears as a denied request that read nothing.
  # Everyone else, the owner included, fires: CI bursts overlap break-glass
  # volume, so a count threshold can't tell a stolen credential from a run.
  audit_expected_principals = "(${join("|", [
    for email in [local.bootstrap.github_deployer_ro_email, local.bootstrap.github_deployer_rw_email] :
    replace(email, ".", "\\.")
  ])})?"
}

# One instance per unexpected principal and service, so a firing alert names
# who touched what. The query aligns the DELTA counter per period (A), sums the
# window (B), and fires on any event (C).
resource "grafana_rule_group" "gcp_audit" {
  name             = "GCP audit"
  folder_uid       = grafana_folder.gcp_observability.uid
  interval_seconds = 60

  rule {
    name           = "Unexpected Data Access"
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
          projectName = local.bootstrap.project_id
          filters = [
            "metric.type", "=", "logging.googleapis.com/user/${google_logging_metric.audit_data_access.name}",
            "AND", "metric.label.principal", "!=~", local.audit_expected_principals,
          ]
          groupBys           = ["metric.label.principal", "metric.label.service"]
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
        reducer    = "sum"
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
