# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Collectors evaluate pipeline contents themselves, so the literal
# sys.env("GCLOUD_RW_API_KEY") stays in each template and the token never reaches
# this state. A pipeline runs in its own scope and can't share another's writer,
# so each template carries its own.

resource "grafana_fleet_management_collector" "nanopi_neo3" {
  provider = grafana.fleet_management

  id = "NanoPi-NEO3"
}

import {
  to = grafana_fleet_management_collector.nanopi_neo3
  id = "NanoPi-NEO3"
}

# Matchers select on an attribute per concern rather than on a collector's ID, so
# a pipeline stays unchanged as collectors adopt it. A collector opts in from its
# remotecfg attributes, which is also what makes cutover atomic: a collector can't
# run a pipeline and the local config it replaces unless its own config says so.
resource "grafana_fleet_management_pipeline" "node_metrics" {
  provider = grafana.fleet_management

  name     = "node_metrics"
  enabled  = true
  matchers = ["node_metrics=\"true\""]

  contents = templatefile("${path.module}/alloy-node-metrics.alloy.tftpl", {
    prometheus_url     = local.bootstrap.grafana_prometheus_remote_write_endpoint
    prometheus_user_id = local.bootstrap.grafana_prometheus_user_id
  })
}

resource "grafana_fleet_management_pipeline" "journal_logs" {
  provider = grafana.fleet_management

  name     = "journal_logs"
  enabled  = true
  matchers = ["journal_logs=\"true\""]

  contents = templatefile("${path.module}/alloy-journal-logs.alloy.tftpl", {
    logs_url     = local.bootstrap.grafana_logs_url
    logs_user_id = local.bootstrap.grafana_logs_user_id
  })
}
