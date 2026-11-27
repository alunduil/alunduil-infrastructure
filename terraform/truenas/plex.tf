# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

locals {
  plex_user  = 972
  plex_group = 3002
}

# Plex writes its useful logs to files, not stdout. They live on their own
# dataset so they survive restarts, alloy can read them, and the snapshot tasks
# can leave them out.
resource "truenas_dataset" "plex_logs" {
  name = "${local.pool}/plex/logs"
}

# The chart's host_path storage has no auto_permissions setting, so nothing else
# hands the dataset to the Plex user.
resource "truenas_filesystem_permissions" "plex_logs" {
  path = truenas_dataset.plex_logs.mountpoint
  mode = "0755"
  uid  = local.plex_user
  gid  = local.plex_group
}

resource "truenas_app" "plex" {
  name        = "plex"
  catalog_app = "plex"
  train       = "stable"

  # Declare every top-level key whole; see truenas_app.tailscale. claim_token
  # is left out: Plex reads it only before the server is claimed.
  values = jsonencode({
    TZ     = "Europe/London"
    labels = []
    network = {
      dns_opts     = []
      host_network = false
      networks     = []
      web_port     = { bind_mode = "published", host_ips = [], port_number = 32400 }
    }
    plex = {
      additional_envs  = []
      allowed_networks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      devices          = []
      image_selector   = "image"
    }
    resources = {
      gpus   = { kfd_device_exists = false, nvidia_gpu_selection = {}, use_all_gpus = false }
      limits = { cpus = 2, memory = 4096 }
    }
    run_as = { user = local.plex_user, group = local.plex_group }
    storage = {
      config = {
        type             = "host_path"
        host_path_config = { acl_enable = false, path = "/mnt/${local.pool}/plex" }
      }
      data = {
        type             = "ix_volume"
        ix_volume_config = { acl_enable = false, dataset_name = "data" }
      }
      logs = {
        type             = "host_path"
        host_path_config = { acl_enable = false, path = truenas_filesystem_permissions.plex_logs.path }
      }
      transcode = { type = "temporary" }
      additional_storage = [
        {
          type             = "host_path"
          read_only        = true
          mount_path       = "/media"
          host_path_config = { acl_enable = false, path = "/mnt/${local.pool}/media" }
        },
      ]
    }
  })
}

import {
  to = truenas_app.plex
  id = "plex"
}
