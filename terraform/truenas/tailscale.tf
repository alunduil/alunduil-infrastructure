# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Holds the node's identity. Losing it re-enrolls TrueNAS as a new device,
# which drops its approved subnet and exit-node routes.
resource "truenas_dataset" "tailscale" {
  name  = "volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/tailscale"
  quota = 1024 * 1024 * 1024
}

resource "truenas_app" "tailscale" {
  name                         = "tailscale"
  custom_app                   = true
  custom_compose_config_string = file("${path.module}/tailscale/compose.yaml")

  depends_on = [truenas_dataset.tailscale]
}

import {
  to = truenas_app.tailscale
  id = "tailscale"
}
