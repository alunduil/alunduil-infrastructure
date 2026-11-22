# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

locals {
  # TS_SERVE_CONFIG has to point inside this mount. containerboot treats a
  # missing serve file as no serve config and logs no error.
  tailscale_config_directory = "/config"
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
        { name = "TS_SERVE_CONFIG", value = "${local.tailscale_config_directory}/serve.json" },
      ]
    }
    network = { host_network = true }
    storage = {
      state = {
        type             = "ix_volume"
        ix_volume_config = { acl_enable = false, dataset_name = "state" }
      }
      # The provider can't write files, so tailscale/serve.json is copied
      # into this volume by hand.
      additional_storage = [
        {
          type             = "ix_volume"
          read_only        = true
          mount_path       = local.tailscale_config_directory
          ix_volume_config = { acl_enable = false, dataset_name = "config" }
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
