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

# One pipeline per concern. A key names the template, the pipeline, and the
# attribute a collector sets in its remotecfg to opt in, so a collector can't run
# a pipeline alongside the local config it replaces unless its own config says so.
resource "grafana_fleet_management_pipeline" "concern" {
  for_each = toset(["journal_logs", "node_metrics"])

  provider = grafana.fleet_management

  name     = each.key
  enabled  = true
  matchers = ["${each.key}=\"true\""]

  contents = templatefile("${path.module}/${each.key}.alloy.tftpl", {
    logs_url           = local.bootstrap.grafana_logs_url
    logs_user_id       = local.bootstrap.grafana_logs_user_id
    prometheus_url     = local.bootstrap.grafana_prometheus_remote_write_endpoint
    prometheus_user_id = local.bootstrap.grafana_prometheus_user_id
  })
}
