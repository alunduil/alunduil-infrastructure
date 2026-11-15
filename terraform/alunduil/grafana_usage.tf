# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

data "grafana_data_source" "usage" {
  uid = "grafanacloud-usage"
}

locals {
  usage_data_source = {
    type = data.grafana_data_source.usage.type
    uid  = data.grafana_data_source.usage.uid
  }
}

locals {
  # Monthly overage across the organization, on top of the base plan. Equals
  # UptimeRobot's 144 USD a year, which Grafana Cloud replaces.
  usage_budget_usd = 12

  usage_spend_levels = [
    for level in [
      { percent = 80, uid = "dg3gvrq2zwlj4f" },
      { percent = 100, uid = "bg3gvrqguwuf4a" },
      ] : merge(level, {
        threshold = local.usage_budget_usd * level.percent / 100
        title     = format("%d%% of $%d", level.percent, local.usage_budget_usd)
    })
  ]

  # grafanacloud-usage reports on every stack, and this repository owns only
  # this one.
  usage_stack_selector = "{stack_id=\"1273682\"}"

  usage_anomalies = [
    for anomaly in [
      { product = "Metrics", uid = "dg3gvdzuups00f", selector = "grafanacloud_instance_active_series${local.usage_stack_selector}" },
      { product = "Logs", uid = "eg3gveqh5ovswf", selector = "grafanacloud_logs_instance_bytes_received_per_second${local.usage_stack_selector}" },
      ] : merge(anomaly, {
        current  = "sum by (stack_id) (avg_over_time(${anomaly.selector} [24h]))"
        baseline = "sum by (stack_id) (avg_over_time(${anomaly.selector} [7d] offset 168h))"
        spread   = "sum by (stack_id) (stddev_over_time(${anomaly.selector} [7d] offset 168h))"
    })
  ]

  # These match what the Cost Management and Billing app writes, because it lists
  # them on its Usage Alerts tab.
  usage_alerts = concat(
    [
      for anomaly in local.usage_anomalies : {
        uid    = anomaly.uid
        name   = "Anomaly: ${anomaly.product} Usage (Low sensitivity)"
        labels = { alert_type = "anomaly", product = anomaly.product }
        annotations = {
          alert_type             = "anomaly"
          averaging_window       = "24h"
          buffer_percentage      = "0.1"
          include_drop_anomalies = "true"
          offset_hours           = "168h"
          product                = anomaly.product
          reference_range        = "7d"
          sensitivity            = "low"
          std_deviations         = "3.5"
        }
        expr = join("\n  ", [
          "# Anomaly alert: 24h avg vs 7d baseline ±3.5σ (10% buffer)",
          "(${anomaly.current} - (${anomaly.baseline} * 1.1 + 3.5 * ${anomaly.spread}) > bool 0)",
          "or ((${anomaly.current} - clamp_min(${anomaly.baseline} * 0.9 - 3.5 * ${anomaly.spread}, 0) < bool 0))",
        ])
      }
    ],
    [
      for level in local.usage_spend_levels : {
        uid    = level.uid
        name   = "Global Spend: ${level.title}"
        labels = { product = "Global Spend", threshold = level.title }
        annotations = {
          actual_threshold = tostring(level.threshold)
          alert_type       = "threshold_percent"
          description      = "If the month ends over budget, file an issue to find and fix the source. If it ends under budget, no optimisation is needed."
          overage          = "false"
          percent          = tostring(level.percent)
          product          = "Global Spend"
          threshold        = tostring(local.usage_budget_usd)
        }
        expr = "# Alert when usage exceeds ${level.title}\n grafanacloud_org_total_overage > bool ${level.threshold}"
      }
    ],
  )
}

import {
  to = grafana_rule_group.usage_alerts
  id = "1:grafana-cmab-usage-alerts:Usage Alerts Rule Group"
}

# Applying replaces the whole group, so add any alert created on the Usage Alerts
# tab here too, or it disappears.
resource "grafana_rule_group" "usage_alerts" {
  name             = "Usage Alerts Rule Group"
  folder_uid       = "grafana-cmab-usage-alerts"
  interval_seconds = 60

  dynamic "rule" {
    for_each = local.usage_alerts

    content {
      uid            = rule.value.uid
      name           = rule.value.name
      condition      = "A"
      for            = "1m"
      no_data_state  = "KeepLast"
      exec_err_state = "KeepLast"
      labels         = merge(rule.value.labels, { __grafana_origin = "plugin/grafana-cmab-app" })
      annotations = merge(rule.value.annotations, {
        contact_point = grafana_contact_point.alunduil.name
        summary       = "This alert is provisioned by the Grafana Cloud Cost Management and Billing app."
      })

      notification_settings {
        contact_point = grafana_contact_point.alunduil.name
      }

      data {
        ref_id         = "A"
        datasource_uid = local.usage_data_source.uid
        relative_time_range {
          from = 600
          to   = 0
        }
        model = jsonencode({
          datasource    = local.usage_data_source
          expr          = rule.value.expr
          hide          = false
          instant       = true
          intervalMs    = 1000
          legendFormat  = "__auto"
          maxDataPoints = 43200
          range         = false
          refId         = "A"
        })
      }
    }
  }
}

# Alert rules must live in a folder, and deleting a Git Sync folder deletes the
# alert rules inside it without recreating them, so this gets its own.
resource "grafana_folder" "ingestion" {
  title = "Grafana Cloud ingestion"
  uid   = "grafana-cloud-ingestion"
}

# Rejected samples aren't a cost, so this stays out of the Usage Alerts group.
resource "grafana_rule_group" "ingestion" {
  name             = "Ingestion"
  folder_uid       = grafana_folder.ingestion.uid
  interval_seconds = 300

  rule {
    name      = "Samples discarded"
    condition = "C"
    # Discards spike briefly and clear on their own.
    for            = "1h"
    no_data_state  = "OK"
    exec_err_state = "Error"
    labels         = { severity = "warning" }
    annotations    = { summary = "Grafana Cloud is rejecting samples, so metrics are missing." }

    data {
      ref_id         = "A"
      datasource_uid = local.usage_data_source.uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        refId      = "A"
        datasource = local.usage_data_source
        instant    = true
        range      = false
        expr       = "sum by (reason) (grafanacloud_instance_samples_discarded_per_second)"
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
        expression = "A"
        conditions = [{ evaluator = { type = "gt", params = [0] } }]
      })
    }
  }
}
