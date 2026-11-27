# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# alloy's local config is only a remotecfg bootstrap. Fleet Management serves
# its pipelines, which terraform/alunduil/grafana_fleet_management.tf declares.
locals {
  alloy_config_file      = "config.alloy"
  alloy_config_directory = "/etc/alloy"
  alloy_config_volume    = "config"
  alloy_data_directory   = "/var/lib/alloy/data"

  # The container_logs pipeline dials this path inside the container.
  alloy_docker_socket = "/var/run/docker.sock"

  # The plex_logs pipeline tails files under this path inside the container.
  alloy_plex_logs = "/var/log/plex"

  alloy_config = templatefile("${path.module}/alloy/${local.alloy_config_file}.tftpl", {
    fleet_management_url     = local.bootstrap.grafana_fleet_management_url
    fleet_management_user_id = local.bootstrap.grafana_fleet_management_user_id

    # Matches grafana_fleet_management_collector.truenas in terraform/alunduil/.
    collector_id = "truenas"

    # One attribute per pipeline lets each move to its own collector without
    # editing the pipeline's matcher.
    pipelines = ["container_logs", "netdata_scrape", "plex_logs", "printer_syslog", "slzb_syslog", "truenas_syslog"]
  })
}

resource "truenas_app" "alloy" {
  name        = "alloy"
  catalog_app = "ix-app"
  train       = "stable"

  # Declare every top-level key whole; see truenas_app.tailscale. envs is left
  # out to keep GCLOUD_RW_API_KEY out of this state.
  # docs/how-to/configure-alloy-push-credential.md sets it by hand.
  #
  # With host networking, the served pipelines bind their listener ports without
  # an edit here and label telemetry with the host's hostname.
  values = jsonencode({
    TZ = "Europe/London"
    image = {
      repository  = "grafana/alloy"
      tag         = "latest"
      pull_policy = "missing"
    }
    command = [
      "run",
      "--storage.path=${local.alloy_data_directory}",
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
        mount_path       = local.alloy_data_directory
        ix_volume_config = { acl_enable = false, dataset_name = "storage_entry" }
      },
      # read_only doesn't narrow the Docker API, so this grants control of every
      # container on the box.
      {
        type             = "host_path"
        read_only        = true
        mount_path       = local.alloy_docker_socket
        host_path_config = { acl_enable = false, path = local.alloy_docker_socket }
      },
      {
        type             = "host_path"
        read_only        = true
        mount_path       = local.alloy_plex_logs
        host_path_config = { acl_enable = false, path = truenas_filesystem_permissions.plex_logs.path }
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

action "truenas_app_redeploy" "alloy" {
  config {
    app_name = truenas_app.alloy.name
  }
}
