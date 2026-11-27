# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

locals {
  # containerboot treats a missing serve file as no serve config and logs no
  # error, so every path to the file comes from these values.
  tailscale_serve_file       = "serve.json"
  tailscale_config_directory = "/config"

  tailscale_config_volume = "config"
}

resource "truenas_app" "tailscale" {
  name        = "tailscale"
  catalog_app = "tailscale"
  train       = "community"

  # Declare every top-level key whole. For each key app.update receives, it
  # resets the fields left out to their chart defaults. auth_key stays empty,
  # because auth_once skips login while the node's state is logged in.
  values = jsonencode({
    TZ     = "Europe/London"
    labels = []
    tailscale = {
      hostname            = "truenas"
      auth_once           = true
      reset               = false
      accept_dns          = false
      userspace           = false
      accept_routes       = false
      advertise_exit_node = true
      advertise_routes    = ["192.168.68.0/22"]
      extra_args          = []
      tailscaled_args     = []
      additional_envs = [
        # The chart drops NET_BIND_SERVICE and exposes no setting to add it,
        # so tailscaled logs "localListener failed to listen on <tailnet
        # IP>:443" on every retry. That listener only carries connections from
        # TrueNAS to its own serve URL; netstack answers serve traffic from
        # peers.
        { name = "TS_SERVE_CONFIG", value = "${local.tailscale_config_directory}/${local.tailscale_serve_file}" },
      ]
    }
    network = { host_network = true }
    storage = {
      state = {
        type             = "ix_volume"
        ix_volume_config = { acl_enable = false, dataset_name = "state" }
      }
      additional_storage = [
        {
          type             = "ix_volume"
          read_only        = true
          mount_path       = local.tailscale_config_directory
          ix_volume_config = { acl_enable = false, dataset_name = local.tailscale_config_volume }
        },
      ]
    }
    resources = { limits = { cpus = 2, memory = 256 } }
  })
}

import {
  to = truenas_app.tailscale
  id = "tailscale"
}
