# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Records the DORA metrics in docs/reference/delivery-metrics.md. A release
# ships PRs merged before a dashboard panel's time range can reach, and a
# recording rule sets each query's range. A rule runs its queries one after
# another, so each repository gets its own rules to stay inside the
# evaluation timeout.

locals {
  dora_window_seconds = 30 * 86400

  # A push or merge deploy ships PRs merged moments before it, so a day past
  # the window covers them.
  dora_short_lookback_seconds = local.dora_window_seconds + 86400
  dora_long_lookback_seconds  = 2 * 365 * 86400

  # Workflow and filter per the doc's Repositories table. An empty event
  # matches any event.
  dora_repositories = {
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

  dora_targets = {
    for name, repo in local.dora_repositories : name => merge(repo, {
      ships_by_commit = repo.class == "run" && contains(["", "push"], repo.event)
      lookback_seconds = (
        repo.class == "merge" || (repo.class == "run" && contains(["", "push"], repo.event))
        ? local.dora_short_lookback_seconds
        : local.dora_long_lookback_seconds
      )
    })
  }

  dora_queries = {
    for name, repo in local.dora_targets : name => concat(
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
        options    = { gitRef = "main" }
      }] : [],
      [{
        ref_id     = "P"
        query_type = "Pull_Requests"
        # timeField 2 searches by merged_at.
        options = { timeField = 2, query = "is:merged author:alunduil" }
      }],
    )
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
  interval_seconds = 3600

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
        for_each = local.dora_queries[each.key]

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
