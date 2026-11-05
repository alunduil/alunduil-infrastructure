# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Collectors evaluate pipeline contents themselves, so templates read the push
# token from the collector's environment and it stays out of this state. Pipelines
# can't share components, so each template carries its own writer.

resource "grafana_fleet_management_collector" "nanopi_neo3" {
  provider = grafana.fleet_management

  id = "NanoPi-NEO3"
}

import {
  to = grafana_fleet_management_collector.nanopi_neo3
  id = "NanoPi-NEO3"
}

# A collector opts in to a pipeline by setting the attribute of the same name in
# its remotecfg.
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
