# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Collectors evaluate pipeline contents themselves, so templates read the push
# token from the collector's environment and it stays out of this state. Pipelines
# can't share components, so each renders its own copy of a writer template.

resource "grafana_fleet_management_collector" "nanopi_neo3" {
  provider = grafana.fleet_management

  id = "NanoPi-NEO3"
}

import {
  to = grafana_fleet_management_collector.nanopi_neo3
  id = "NanoPi-NEO3"
}

resource "grafana_fleet_management_collector" "truenas" {
  provider = grafana.fleet_management

  id = "truenas"
}

import {
  to = grafana_fleet_management_collector.truenas
  id = "truenas"
}

# A collector opts in to a pipeline by setting the attribute of the same name in
# its remotecfg. The TrueNAS pipelines stay disabled while the box's local
# config binds the same syslog sockets and scrapes netdata under the same
# labels; enable them in the change that removes those local components.
resource "grafana_fleet_management_pipeline" "concern" {
  for_each = {
    journal_logs   = { enabled = true, template = "journal_logs", listener = null }
    node_metrics   = { enabled = true, template = "node_metrics", listener = null }
    truenas_syslog = { enabled = false, template = "truenas_syslog", listener = null }
    netdata_scrape = { enabled = false, template = "netdata_scrape", listener = null }

    slzb_syslog = {
      enabled  = false
      template = "device_syslog"
      listener = { device = "slzb-mr4u", address = "0.0.0.0:1514", protocol = "udp", syslog_format = "rfc3164" }
    }

    printer_syslog = {
      enabled  = false
      template = "device_syslog"
      listener = { device = "printer", address = "0.0.0.0:1515", protocol = "tcp", syslog_format = "rfc5424" }
    }
  }

  provider = grafana.fleet_management

  name     = each.key
  enabled  = each.value.enabled
  matchers = ["${each.key}=\"true\""]

  contents = templatefile("${path.module}/${each.value.template}.alloy.tftpl", {
    listener = each.value.listener

    loki_write = chomp(templatefile("${path.module}/loki_write.alloy.tftpl", {
      pipeline     = each.key
      logs_url     = local.bootstrap.grafana_logs_url
      logs_user_id = local.bootstrap.grafana_logs_user_id
    }))

    prometheus_remote_write = chomp(templatefile("${path.module}/prometheus_remote_write.alloy.tftpl", {
      pipeline           = each.key
      prometheus_url     = local.bootstrap.grafana_prometheus_remote_write_endpoint
      prometheus_user_id = local.bootstrap.grafana_prometheus_user_id
    }))
  })
}
