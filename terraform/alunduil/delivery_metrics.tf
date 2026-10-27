# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Recording rules compute the DORA metrics in docs/reference/delivery-metrics.md
# and write them to Prometheus for grafana/delivery-metrics.json. A dashboard
# panel can't look further back than its time range, but a release ships every
# PR since the previous release, often months earlier; a rule sets each query's
# range on its own. A rule runs its queries one after another, so each
# repository gets its own rules to stay inside the evaluation timeout.

locals {
  delivery_window_seconds = 30 * 86400

  # A push or merge deploy ships PRs merged moments before it, so a day past
  # the window covers them. A release ships everything since the previous
  # deploy, which can be long before the window opens.
  delivery_short_lookback_seconds = local.delivery_window_seconds + 86400
  delivery_long_lookback_seconds  = 2 * 365 * 86400

  # Workflow and filter per the doc's Repositories table. An empty event
  # matches any event.
  delivery_repositories = {
    "alunduil-infrastructure" = { class = "run", workflow = "terraform-apply.yml", branch = "main", event = "" }
    "blog.alunduil.com"       = { class = "run", workflow = "cd.yml", branch = "main", event = "push" }
    "collection-json.hs"      = { class = "run", workflow = "release.yml", branch = "", event = "workflow_dispatch" }
    "network-arbitrary"       = { class = "run", workflow = "release.yml", branch = "", event = "release" }
    "zfs-replicate"           = { class = "run", workflow = "release.yml", branch = "", event = "release" }
    "woodland-generators"     = { class = "release", workflow = "", branch = "", event = "" }
    "siren-json.hs"           = { class = "release", workflow = "", branch = "", event = "" }
    "renovate-config"         = { class = "merge", workflow = "", branch = "", event = "" }
    "alunduil-chezmoi"        = { class = "merge", workflow = "", branch = "", event = "" }
  }

  # Recorded metric name suffix to the template's metric and statistic.
  delivery_metrics = {
    deploys                      = { metric = "deploys", statistic = "" }
    lead_time_seconds_bucket     = { metric = "lead_time", statistic = "bucket" }
    lead_time_median_seconds     = { metric = "lead_time", statistic = "median" }
    recovery_time_seconds_bucket = { metric = "recovery_time", statistic = "bucket" }
    recovery_time_median_seconds = { metric = "recovery_time", statistic = "median" }
  }

  # Five minutes to sixteen weeks. The dashboard's pooled medians interpolate
  # within these.
  delivery_time_buckets_seconds = [
    300, 900, 1800, 3600, 7200, 14400, 28800,
    86400, 172800, 345600, 604800, 1209600, 2419200, 4838400, 9676800,
  ]

  delivery_queries = {
    for name, repo in local.delivery_repositories : name => [
      for query in [
        repo.class == "run" ? {
          ref_id     = "R"
          query_type = "Workflow_Runs"
          options    = { workflow = repo.workflow, branch = repo.branch }
        } : null,
        repo.class == "release" ? {
          ref_id     = "R"
          query_type = "Releases"
          options    = {}
        } : null,
        repo.class == "run" && contains(["", "push"], repo.event) ? {
          ref_id     = "C"
          query_type = "Commits"
          options    = { gitRef = "main" }
        } : null,
        {
          ref_id     = "P"
          query_type = "Pull_Requests"
          # timeField 2 searches by merged_at.
          options = { timeField = 2, query = "is:merged author:alunduil" }
        },
        ] : merge(query, {
          from = (
            repo.class == "merge" || contains(["", "push"], repo.event)
            ? local.delivery_short_lookback_seconds
            : local.delivery_long_lookback_seconds
          )
      }) if query != null
    ]
  }
}

resource "grafana_folder" "delivery" {
  title = "Delivery metrics"
  uid   = "delivery-metrics"
}

resource "grafana_rule_group" "delivery" {
  for_each = local.delivery_repositories

  name             = each.key
  folder_uid       = grafana_folder.delivery.uid
  interval_seconds = 3600

  dynamic "rule" {
    for_each = local.delivery_metrics

    content {
      name   = "${each.key} ${rule.key}"
      labels = { repository = each.key }

      record {
        metric = "delivery_${rule.key}"
        from   = "OUT"
      }

      dynamic "data" {
        for_each = local.delivery_queries[each.key]

        content {
          ref_id         = data.value.ref_id
          query_type     = data.value.query_type
          datasource_uid = grafana_data_source.github.uid
          relative_time_range {
            from = data.value.from
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
          from = local.delivery_window_seconds
          to   = 0
        }
        model = jsonencode({
          refId      = "OUT"
          type       = "sql"
          datasource = { type = "__expr__", uid = "__expr__" }
          # Each row becomes a series: the numeric column its value, the
          # string columns its labels.
          format = "alerting"
          expression = templatefile("${path.module}/delivery-metrics.sql.tftpl", {
            class          = each.value.class
            event          = each.value.event
            commits        = each.value.class == "run" && contains(["", "push"], each.value.event)
            metric         = rule.value.metric
            statistic      = rule.value.statistic
            window_seconds = local.delivery_window_seconds
            buckets        = local.delivery_time_buckets_seconds
          })
        })
      }
    }
  }
}
