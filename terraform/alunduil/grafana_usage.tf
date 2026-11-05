# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Alerts on Grafana Cloud's bill. grafana/grafana-cloud-usage.json plots the
# same series and repeats the budget as constants, so a new budget changes both.

data "grafana_data_source" "usage" {
  uid = "grafanacloud-usage"
}

locals {
  # Monthly overage on top of the base plan: what UptimeRobot costs at 144 USD a
  # year, which Grafana Cloud replaces.
  usage_overage_budget_usd = 12

  # The 6h hold rides out restart spikes in ingest.
  usage_hold = "6h"

  usage_allowance_threshold = 0.8

  # Each ratio carries a product label because the ratios otherwise share a
  # labelset, and `or` would keep only the first.
  usage_allowance_expr = join(" or ", [
    for product in ["logs", "traces", "profiles"] :
    "label_replace(grafanacloud_org_${product}_usage / grafanacloud_org_${product}_included_usage, \"product\", \"${product}\", \"\", \"\")"
  ])

  usage_rules = {
    "Overage nearing budget" = {
      summary   = "Grafana Cloud overage this month is above 80% of the budget."
      expr      = "grafanacloud_org_total_overage"
      threshold = 0.8 * local.usage_overage_budget_usd
      for       = local.usage_hold
    }
    "Overage over budget" = {
      summary   = "Grafana Cloud overage this month is above the budget. If the month ends over budget, file an issue to find and fix the source. If it ends under budget, no optimisation is needed."
      expr      = "grafanacloud_org_total_overage"
      threshold = local.usage_overage_budget_usd
      for       = local.usage_hold
    }
    "Usage near included allowance" = {
      summary   = "A Grafana Cloud product is above 80% of its included allowance."
      expr      = local.usage_allowance_expr
      threshold = local.usage_allowance_threshold
      for       = local.usage_hold
    }
    "Samples discarded" = {
      summary   = "Grafana Cloud is rejecting samples, so metrics are missing."
      expr      = "sum by (reason) (grafanacloud_instance_samples_discarded_per_second)"
      threshold = 0
      # Discards spike briefly during restarts and clear without intervention.
      for = "1h"
    }
  }
}

# Alert rules must live in a folder, and deleting a Git Sync folder deletes the
# alert rules inside it without recreating them, so these get their own.
resource "grafana_folder" "usage" {
  title = "Grafana Cloud usage"
  uid   = "grafana-cloud-usage"
}

resource "grafana_rule_group" "usage" {
  name             = "Usage"
  folder_uid       = grafana_folder.usage.uid
  interval_seconds = 300

  dynamic "rule" {
    for_each = local.usage_rules

    content {
      name           = rule.key
      condition      = "C"
      for            = rule.value.for
      no_data_state  = "OK"
      exec_err_state = "Error"
      labels         = { severity = "warning" }
      annotations    = { summary = rule.value.summary }

      data {
        ref_id         = "A"
        datasource_uid = data.grafana_data_source.usage.uid
        relative_time_range {
          from = 600
          to   = 0
        }
        model = jsonencode({
          refId      = "A"
          datasource = { type = data.grafana_data_source.usage.type, uid = data.grafana_data_source.usage.uid }
          instant    = true
          range      = false
          expr       = rule.value.expr
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
          conditions = [{ evaluator = { type = "gt", params = [rule.value.threshold] } }]
        })
      }
    }
  }
}
