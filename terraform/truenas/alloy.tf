# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The local config is only a remotecfg bootstrap: Fleet Management serves the
# pipelines from terraform/alunduil/grafana_fleet_management.tf.
locals {
  alloy_config_file      = "config.alloy"
  alloy_config_directory = "/etc/alloy"
  alloy_config_volume    = "config"

  alloy_config = templatefile("${path.module}/alloy/${local.alloy_config_file}.tftpl", {
    fleet_management_url     = local.bootstrap.grafana_fleet_management_url
    fleet_management_user_id = local.bootstrap.grafana_fleet_management_user_id

    # terraform/alunduil/'s grafana_fleet_management_collector declares this ID.
    collector_id = "truenas"

    # One attribute per pipeline lets each move to its own collector without
    # editing the pipeline's matcher.
    pipelines = ["netdata_scrape", "printer_syslog", "slzb_syslog", "truenas_syslog"]
  })
}

resource "truenas_app" "alloy" {
  name        = "alloy"
  catalog_app = "ix-app"
  train       = "stable"

  # Declare every top-level key whole; see truenas_app.tailscale. envs is left
  # out so GCLOUD_RW_API_KEY, set by hand from
  # docs/how-to/configure-alloy-push-credential.md, stays out of this state.
  #
  # Host networking gives the container the host's hostname, which the served
  # pipelines label telemetry with, and lets them bind listener ports without a
  # matching edit here.
  values = jsonencode({
    TZ = "Europe/London"
    image = {
      repository  = "grafana/alloy"
      tag         = "latest"
      pull_policy = "missing"
    }
    command = [
      "run",
      "--storage.path=/var/lib/alloy/data",
      "${local.alloy_config_directory}/${local.alloy_config_file}",
      "--server.http.listen-addr=0.0.0.0:12345",
    ]
    host_network = true
    ports        = []
    storage = [
      {
        type             = "ix_volume"
        read_only        = true
        mount_path       = local.alloy_config_directory
        ix_volume_config = { acl_enable = false, dataset_name = local.alloy_config_volume }
      },
      {
        type             = "ix_volume"
        read_only        = false
        mount_path       = "/var/lib/alloy/data"
        ix_volume_config = { acl_enable = false, dataset_name = "storage_entry" }
      },
    ]
    resources = {
      enable_resource_limits = true
      limits                 = { cpus = 2, memory = 512 }
    }
  })
}

import {
  to = truenas_app.alloy
  id = "alloy"
}
