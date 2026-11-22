# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Holds the serve config the tailscale app reads. The provider can't write
# files, so tailscale/serve.json is copied here by hand.
resource "truenas_dataset" "tailscale" {
  name  = "volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/tailscale"
  quota = 1024 * 1024 * 1024
}

resource "truenas_app" "tailscale" {
  name        = "tailscale"
  catalog_app = "tailscale"
  train       = "community"

  # app.update replaces each top-level key it receives, so each is declared
  # whole. auth_key is left empty: auth_once skips login while the node's
  # state is logged in.
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
        { name = "TS_SERVE_CONFIG", value = "/config/serve.json" },
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
          type             = "host_path"
          read_only        = true
          mount_path       = "/config"
          host_path_config = { acl_enable = false, path = "/mnt/${truenas_dataset.tailscale.name}" }
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
