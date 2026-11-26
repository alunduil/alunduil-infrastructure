# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# values reads back every key it declares into state, so envs stays out of it to
# keep the push credential off the state bucket.
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
    ]
  })
}

import {
  to = truenas_app.alloy
  id = "alloy"
}
