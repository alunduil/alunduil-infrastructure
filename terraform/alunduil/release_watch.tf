# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Alerts on a published version or Release that no expected flow created.
# docs/how-to/respond-to-an-unexpected-release.md says what to do when one
# fires. A registry upload can't be recalled, so these alerts decide how long
# a bad one goes unnoticed.

locals {
  # A registry version matches the tag named after it, with or without a
  # leading v. untagged lists versions published without a tag before this
  # check existed.
  release_watch = {
    "collection-json.hs"  = { registry = "hackage", package = "collection-json", untagged = ["0.1.0.0"] }
    "network-arbitrary"   = { registry = "hackage", package = "network-arbitrary" }
    "siren-json.hs"       = { registry = "hackage", package = "siren-json" }
    "woodland-generators" = {}
    "zellij-claude-pair"  = {}
    "zfs-replicate"       = { registry = "pypi", package = "zfs-replicate", untagged = ["1.1.6", "1.2.1", "1.2.2", "1.2.3"] }
  }

  release_expected_creators = ["alunduil"]

  release_watch_interval_seconds = 3600

  # Releases created inside the window fire, so one fires for a day.
  release_window_seconds = 86400

  # The Tags query drops tags dated outside the rule's time range, by tagger
  # or commit date, so the range reaches back past every tag.
  release_tag_lookback_seconds = 20 * 365 * 86400

  # Hackage's preferred-versions document lists deprecated versions apart
  # from the rest, and a deprecated version still installs when pinned.
  release_registry_queries = {
    hackage = {
      url     = "https://hackage.haskell.org/package/%s/preferred"
      headers = [{ key = "Accept", value = "application/json" }]
      jq      = "(.[\"normal-version\"] + (.[\"deprecated-version\"] // []))[] | {version: .}"
    }
    pypi = {
      url     = "https://pypi.org/pypi/%s/json"
      headers = []
      jq      = ".releases | keys[] | {version: .}"
    }
  }

  release_expected_creators_sql = join(", ", [for login in local.release_expected_creators : "'${login}'"])

  release_untagged_rules = {
    for name, repo in local.release_watch : "${name} version has no tag" => {
      repository = name
      window     = local.release_watch_interval_seconds
      queries = [
        {
          ref_id     = "R"
          datasource = grafana_data_source.registries
          query_type = null
          from       = local.release_watch_interval_seconds
          model = {
            type          = "json"
            source        = "url"
            format        = "table"
            parser        = "jq-backend"
            url           = format(local.release_registry_queries[repo.registry].url, repo.package)
            url_options   = { method = "GET", headers = local.release_registry_queries[repo.registry].headers }
            root_selector = local.release_registry_queries[repo.registry].jq
            columns       = [{ selector = "version", text = "version", type = "string" }]
          }
        },
        {
          ref_id     = "T"
          datasource = grafana_data_source.github
          query_type = "Tags"
          from       = local.release_tag_lookback_seconds
          model      = { owner = "alunduil", repository = name, options = {} }
        },
      ]
      sql = join("\n", compact([
        "SELECT version, 1 AS untagged FROM R",
        "WHERE version NOT IN (SELECT name FROM T)",
        "AND CONCAT('v', version) NOT IN (SELECT name FROM T)",
        length(lookup(repo, "untagged", [])) > 0 ? "AND version NOT IN (${join(", ", [for v in repo.untagged : "'${v}'"])})" : "",
      ]))
    }
    if contains(keys(repo), "registry")
  }

  # The Releases query keeps only published Releases, so a draft fires once
  # it's published.
  release_creator_rules = {
    for name, repo in local.release_watch : "${name} Release by an unexpected account" => {
      repository = name
      window     = local.release_window_seconds
      queries = [{
        ref_id     = "R"
        datasource = grafana_data_source.github
        query_type = "Releases"
        from       = local.release_window_seconds
        model      = { owner = "alunduil", repository = name, options = {} }
      }]
      sql = "SELECT tag, created_by, 1 AS unexpected FROM R WHERE created_by NOT IN (${local.release_expected_creators_sql})"
    }
  }

  release_rules = merge(local.release_untagged_rules, local.release_creator_rules)
}

resource "grafana_data_source" "registries" {
  type = "yesoreyeram-infinity-datasource"
  name = "Package registries"
  uid  = "registries"

  json_data_encoded = jsonencode({
    allowedHosts = ["https://hackage.haskell.org", "https://pypi.org"]
  })
}

resource "grafana_folder" "release_watch" {
  title = "Releases"
  uid   = "releases"
}

resource "grafana_rule_group" "release_watch" {
  name             = "Unexpected releases"
  folder_uid       = grafana_folder.release_watch.uid
  interval_seconds = local.release_watch_interval_seconds

  dynamic "rule" {
    for_each = local.release_rules

    content {
      name           = rule.key
      condition      = "C"
      for            = "0s"
      no_data_state  = "OK"
      exec_err_state = "Error"
      labels         = { severity = "warning", repository = rule.value.repository }

      dynamic "data" {
        for_each = rule.value.queries

        content {
          ref_id         = data.value.ref_id
          query_type     = data.value.query_type
          datasource_uid = data.value.datasource.uid
          relative_time_range {
            from = data.value.from
            to   = 0
          }
          model = jsonencode(merge(
            {
              refId      = data.value.ref_id
              datasource = { type = data.value.datasource.type, uid = data.value.datasource.uid }
            },
            data.value.query_type == null ? {} : { queryType = data.value.query_type },
            data.value.model,
          ))
        }
      }

      data {
        ref_id         = "OUT"
        datasource_uid = "__expr__"
        relative_time_range {
          from = rule.value.window
          to   = 0
        }
        model = jsonencode({
          refId      = "OUT"
          type       = "sql"
          datasource = { type = "__expr__", uid = "__expr__" }
          format     = "alerting"
          expression = rule.value.sql
        })
      }

      data {
        ref_id         = "C"
        datasource_uid = "__expr__"
        relative_time_range {
          from = rule.value.window
          to   = 0
        }
        model = jsonencode({
          refId      = "C"
          type       = "threshold"
          datasource = { type = "__expr__", uid = "__expr__" }
          expression = "OUT"
          conditions = [{ evaluator = { type = "gt", params = [0] } }]
        })
      }
    }
  }
}
