# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Records the DORA metrics in docs/reference/delivery-metrics.md. A release
# ships PRs merged before a dashboard panel's time range can reach, and a
# recording rule sets each query's range. A rule runs its queries one after
# another, so each repository gets its own rules to stay inside the
# evaluation timeout.

locals {
  dora_window_seconds   = 30 * 86400
  dora_interval_seconds = 3600

  dora_missed_evaluations = 3

  # A push or merge deploy ships PRs merged moments before it, so a day past
  # the window covers them.
  dora_short_lookback_seconds = local.dora_window_seconds + 86400
  dora_long_lookback_seconds  = 2 * 365 * 86400

  dora_metrics = {
    deploys                      = { metric = "deploys", statistic = "" }
    lead_time_seconds_bucket     = { metric = "lead_time", statistic = "bucket" }
    lead_time_median_seconds     = { metric = "lead_time", statistic = "median" }
    recovery_time_seconds_bucket = { metric = "recovery_time", statistic = "bucket" }
    recovery_time_median_seconds = { metric = "recovery_time", statistic = "median" }
  }

  # The dashboard's pooled medians interpolate within these.
  dora_time_buckets_seconds = [
    300, 900, 1800, 3600, 7200, 14400, 28800,
    86400, 172800, 345600, 604800, 1209600, 2419200, 4838400, 9676800,
  ]

  # Kept free of module outputs: the alert rule reads it, and a new resource
  # depending on module.repository cycles with the module's check block.
  dora_repositories = [
    for name, repo in local.repositories : name
    if lookup(repo, "deploy", null) != null
  ]

  dora_deploys = {
    for name in local.dora_repositories : name => merge(
      { workflow = "", branch = "", event = "" },
      local.repositories[name].deploy,
      { default_branch = module.repository[name].default_branch },
    )
  }

  dora_shapes = {
    for name, deploy in local.dora_deploys : name => merge(deploy, {
      ships_by_commit = deploy.class == "run" && contains(["", "push"], deploy.event)
    })
  }

  dora_targets = {
    for name, repo in local.dora_shapes : name => merge(repo, {
      lookback_seconds = (
        repo.class == "merge" || repo.ships_by_commit
        ? local.dora_short_lookback_seconds
        : local.dora_long_lookback_seconds
      )
      queries = concat(
        repo.class == "run" ? [{
          ref_id     = "R"
          query_type = "Workflow_Runs"
          options    = { workflow = repo.workflow, branch = repo.branch }
        }] : [],
        repo.class == "release" ? [{
          ref_id     = "R"
          query_type = "Releases"
          options    = {}
        }] : [],
        repo.ships_by_commit ? [{
          ref_id     = "C"
          query_type = "Commits"
          options    = { gitRef = repo.default_branch }
        }] : [],
        [{
          ref_id     = "P"
          query_type = "Pull_Requests"
          # timeField 2 searches by merged_at.
          options = { timeField = 2, query = "is:merged author:alunduil" }
        }],
      )
    })
  }
}

resource "grafana_folder" "dora" {
  title = "DORA metrics"
  uid   = "dora-metrics"
}

resource "grafana_rule_group" "dora" {
  for_each = local.dora_targets

  name             = each.key
  folder_uid       = grafana_folder.dora.uid
  interval_seconds = local.dora_interval_seconds

  dynamic "rule" {
    for_each = local.dora_metrics

    content {
      name   = "${each.key} ${rule.key}"
      labels = { repository = each.key }

      record {
        metric = "dora_${rule.key}"
        from   = "OUT"
      }

      dynamic "data" {
        for_each = each.value.queries

        content {
          ref_id         = data.value.ref_id
          query_type     = data.value.query_type
          datasource_uid = grafana_data_source.github.uid
          relative_time_range {
            from = each.value.lookback_seconds
            to   = 0
          }
          model = jsonencode({
            refId      = data.value.ref_id
            queryType  = data.value.query_type
            datasource = { type = grafana_data_source.github.type, uid = grafana_data_source.github.uid }
            owner      = "alunduil"
            repository = each.key
            options    = data.value.options
          })
        }
      }

      data {
        ref_id         = "OUT"
        datasource_uid = "__expr__"
        relative_time_range {
          from = local.dora_window_seconds
          to   = 0
        }
        model = jsonencode({
          refId      = "OUT"
          type       = "sql"
          datasource = { type = "__expr__", uid = "__expr__" }
          # Each row becomes a series: the numeric column its value, the
          # string columns its labels.
          format = "alerting"
          expression = templatefile("${path.module}/dora-metrics.sql.tftpl", {
            class           = each.value.class
            event           = each.value.event
            ships_by_commit = each.value.ships_by_commit
            metric          = rule.value.metric
            statistic       = rule.value.statistic
            window_seconds  = local.dora_window_seconds
            buckets         = local.dora_time_buckets_seconds
          })
        })
      }
    }
  }
}

data "grafana_data_source" "prometheus" {
  uid = "grafanacloud-prom"
}

# dora_deploys records both outcomes every evaluation, even with no deploys,
# so its absence means the repository's rules failed. A median series is
# also absent while the window has nothing to measure.
resource "grafana_rule_group" "dora_recording" {
  name             = "Alerts"
  folder_uid       = grafana_folder.dora.uid
  interval_seconds = 300

  rule {
    name           = "DORA rules stopped recording"
    condition      = "C"
    for            = "0s"
    no_data_state  = "OK"
    exec_err_state = "Error"
    labels         = { severity = "warning" }

    data {
      ref_id         = "A"
      datasource_uid = data.grafana_data_source.prometheus.uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        refId      = "A"
        datasource = { type = data.grafana_data_source.prometheus.type, uid = data.grafana_data_source.prometheus.uid }
        instant    = true
        range      = false
        # An equality matcher carries its label onto absent_over_time's
        # result, so each failing repository fires its own alert.
        expr = join(" or ", [
          for name in local.dora_repositories :
          "absent_over_time(dora_deploys{repository=\"${name}\"}[${local.dora_missed_evaluations * local.dora_interval_seconds}s])"
        ])
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
