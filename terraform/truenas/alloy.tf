# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

locals {
  # The container_logs pipeline dials this path inside the container.
  docker_socket = "/var/run/docker.sock"
}

# State records every key that values declares. envs holds the push credential,
# so it stays undeclared.
resource "truenas_app" "alloy" {
  name        = "alloy"
  catalog_app = "ix-app"
  train       = "stable"

  values = jsonencode({
    storage = [
      {
        type             = "host_path"
        read_only        = true
        mount_path       = "/etc/alloy/config.alloy"
        host_path_config = { acl_enable = false, path = "/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/alloy/config.alloy" }
      },
      {
        type             = "ix_volume"
        read_only        = false
        mount_path       = "/var/lib/alloy/data"
        ix_volume_config = { acl_enable = false, dataset_name = "storage_entry" }
      },
      # read_only doesn't narrow the Docker API, so this grants control of every
      # container on the box.
      {
        type             = "host_path"
        read_only        = true
        mount_path       = local.docker_socket
        host_path_config = { acl_enable = false, path = local.docker_socket }
      },
    ]
  })
}

import {
  to = truenas_app.alloy
  id = "alloy"
}
