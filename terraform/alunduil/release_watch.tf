# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Alerts on a registry version with no matching tag, on a Release or tag from
# an unexpected account, and on a published Release that changes.
# docs/how-to/respond-to-an-unexpected-release.md covers the response.

locals {
  # untagged exempts versions published without a tag.
  release_watch = {
    "collection-json.hs"  = { registry = "hackage", package = "collection-json", untagged = ["0.1.0.0"] }
    "network-arbitrary"   = { registry = "hackage", package = "network-arbitrary" }
    "siren-json.hs"       = { registry = "hackage", package = "siren-json" }
    "woodland-generators" = {}
    "zellij-claude-pair"  = {}
    "zfs-replicate"       = { registry = "pypi", package = "zfs-replicate", untagged = ["1.1.6", "1.2.1", "1.2.2", "1.2.3"] }
  }

  release_expected_accounts = ["alunduil"]

  release_watch_interval_seconds = 3600

  # How long an unexpected Release keeps firing.
  release_window_seconds = 86400

  # The Tags query drops any tag whose tagger or commit date falls outside the
  # rule's time range.
  release_tag_lookback_seconds = 20 * 365 * 86400

  # Hackage lists deprecated versions separately, and a pinned build still
  # installs one.
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

  release_expected_accounts_sql = join(", ", [for login in local.release_expected_accounts : "'${login}'"])

  # A create event's sender is the account that pushed the ref. A tag's
  # tagger is whatever the pusher wrote.
  release_tag_unexpected_jinja = "payload.ref_type == \"tag\" and payload.sender.login not in ${jsonencode(local.release_expected_accounts)}"

  # A draft has no published_at.
  release_published_jinja = "payload.release.published_at"
  # Publishing sets updated_at to published_at, and every later edit,
  # prerelease flip included, moves updated_at on. A deletion leaves both alone.
  release_changed_since_publish_jinja = "(payload.action in [\"deleted\", \"unpublished\"] or payload.release.updated_at != payload.release.published_at)"
  # collection-json.hs's release workflow promotes its prerelease this way.
  release_promoted_by_workflow_jinja = "(payload.action == \"released\" and payload.sender.login == \"github-actions[bot]\")"
  release_changed_jinja              = "${local.release_published_jinja} and ${local.release_changed_since_publish_jinja} and not ${local.release_promoted_by_workflow_jinja}"

  # Each alert pages on events matching page. The rest resolve on arrival, and
  # a resolving event resolves its whole alert group.
  release_webhook_alerts = {
    # GitHub can't limit create events to tags, so every new branch arrives
    # here too. GitHub sends no create event for a push of more than three
    # tags, but such a push starts no workflow either, so it can't publish.
    tags = {
      name         = "Release tags"
      event        = "create"
      page         = local.release_tag_unexpected_jinja
      title        = "{{ payload.repository.name }} tag {{ payload.ref }} pushed by {{ payload.sender.login }}"
      grouping_key = "{{ payload.repository.full_name }} {{ payload.ref_type }} {{ payload.ref }}"
      source_link  = "{{ payload.repository.html_url }}/releases/tag/{{ payload.ref }}"
    }
    # The key separates each change from the events that follow it.
    changes = {
      name         = "Release changes"
      event        = "release"
      page         = local.release_changed_jinja
      title        = "{{ payload.repository.name }} Release {{ payload.release.tag_name }} {{ payload.action }} by {{ payload.sender.login }}"
      grouping_key = "{{ payload.repository.full_name }} {{ payload.release.id }} {{ payload.action }} {{ payload.release.updated_at }}"
      source_link  = "{{ payload.release.html_url }}"
    }
  }

  release_webhooks = {
    for pair in setproduct(keys(local.release_webhook_alerts), keys(local.release_watch)) : "${pair[0]} ${pair[1]}" => {
      alert      = pair[0]
      repository = pair[1]
    }
  }

  release_github_models = {
    for name in keys(local.release_watch) : name => { owner = "alunduil", repository = name, options = {} }
  }

  release_registry_targets = {
    for name, repo in local.release_watch : name => merge(local.release_registry_queries[repo.registry], {
      url          = format(local.release_registry_queries[repo.registry].url, repo.package)
      untagged_sql = join(", ", [for v in lookup(repo, "untagged", []) : "'${v}'"])
    })
    if contains(keys(repo), "registry")
  }

  release_untagged_rules = {
    for name, target in local.release_registry_targets : "${name} version has no tag" => {
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
            url           = target.url
            url_options   = { method = "GET", headers = target.headers }
            root_selector = target.jq
            columns       = [{ selector = "version", text = "version", type = "string" }]
          }
        },
        {
          ref_id     = "T"
          datasource = grafana_data_source.github
          query_type = "Tags"
          from       = local.release_tag_lookback_seconds
          model      = local.release_github_models[name]
        },
      ]
      labels = ["version"]
      value  = "untagged"
      sql = join("\n", compact([
        "SELECT version, 1 AS untagged FROM R",
        "WHERE version NOT IN (SELECT name FROM T)",
        "AND CONCAT('v', version) NOT IN (SELECT name FROM T)",
        target.untagged_sql != "" ? "AND version NOT IN (${target.untagged_sql})" : "",
      ]))
    }
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
        model      = local.release_github_models[name]
      }]
      labels = ["tag", "created_by"]
      value  = "unexpected"
      sql    = "SELECT tag, created_by, 1 AS unexpected FROM R WHERE created_by NOT IN (${local.release_expected_accounts_sql})"
    }
  }

  # Grafana puts a rule in Error when its SQL returns no rows, so each rule gets
  # an extra row valued 0, which never fires. labels and value name that row's
  # columns and must match the rule's SELECT in order.
  release_rules = {
    for name, rule in merge(local.release_untagged_rules, local.release_creator_rules) : name => merge(rule, {
      expression = join("\n", [
        rule.sql,
        "UNION ALL SELECT ${join(", ", concat([for l in rule.labels : "'' AS ${l}"], ["0 AS ${rule.value}"]))}",
      ])
    })
  }
}

# Grafana Cloud pre-provisions the Infinity plugin, so bootstrap doesn't install
# it.
resource "grafana_data_source" "registries" {
  type = "yesoreyeram-infinity-datasource"
  name = "Package registries"
  uid  = "registries"

  json_data_encoded = jsonencode({
    allowedHosts = sort(distinct([for q in values(local.release_registry_queries) : regex("^https://[^/]+", q.url)]))
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
      condition      = "OUT"
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

      # Grafana accepts a SQL expression only as a rule's last step. Each row
      # it returns is an alert instance, firing while its numeric column is
      # non-zero.
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
          expression = rule.value.expression
        })
      }
    }
  }
}

resource "grafana_oncall_integration" "release_webhook" {
  for_each = local.release_webhook_alerts

  name = each.value.name
  type = "webhook"

  default_route {}

  templates {
    grouping_key   = each.value.grouping_key
    resolve_signal = "{{ not (${each.value.page}) }}"
    source_link    = each.value.source_link

    web {
      title = each.value.title
    }
    mobile_app {
      title = each.value.title
    }
    sms {
      title = each.value.title
    }
    phone_call {
      title = each.value.title
    }
    email {
      title = each.value.title
    }
  }
}

resource "grafana_oncall_route" "release_webhook" {
  for_each = local.release_webhook_alerts

  integration_id      = grafana_oncall_integration.release_webhook[each.key].id
  escalation_chain_id = grafana_oncall_escalation_chain.alunduil.id
  routing_type        = "jinja2"
  routing_regex       = "{{ ${each.value.page} }}"
  position            = 0
}

resource "github_repository_webhook" "release_webhook" {
  for_each = local.release_webhooks

  repository = each.value.repository
  events     = [local.release_webhook_alerts[each.value.alert].event]

  configuration {
    url          = grafana_oncall_integration.release_webhook[each.value.alert].link
    content_type = "json"
    insecure_ssl = false
  }
}

moved {
  from = grafana_oncall_integration.release_tags
  to   = grafana_oncall_integration.release_webhook["tags"]
}

moved {
  from = grafana_oncall_route.release_tag_unexpected
  to   = grafana_oncall_route.release_webhook["tags"]
}

moved {
  from = github_repository_webhook.release_tags["collection-json.hs"]
  to   = github_repository_webhook.release_webhook["tags collection-json.hs"]
}

moved {
  from = github_repository_webhook.release_tags["network-arbitrary"]
  to   = github_repository_webhook.release_webhook["tags network-arbitrary"]
}

moved {
  from = github_repository_webhook.release_tags["siren-json.hs"]
  to   = github_repository_webhook.release_webhook["tags siren-json.hs"]
}

moved {
  from = github_repository_webhook.release_tags["woodland-generators"]
  to   = github_repository_webhook.release_webhook["tags woodland-generators"]
}

moved {
  from = github_repository_webhook.release_tags["zellij-claude-pair"]
  to   = github_repository_webhook.release_webhook["tags zellij-claude-pair"]
}

moved {
  from = github_repository_webhook.release_tags["zfs-replicate"]
  to   = github_repository_webhook.release_webhook["tags zfs-replicate"]
}
