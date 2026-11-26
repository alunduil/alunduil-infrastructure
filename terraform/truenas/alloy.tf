# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

locals {
  alloy_config_file      = "config.alloy"
  alloy_config_directory = "/etc/alloy"
  alloy_config_volume    = "config"
  alloy_storage_path     = "/var/lib/alloy/data"

  alloy_config = templatefile("${path.module}/alloy/${local.alloy_config_file}.tftpl", {
    url     = local.bootstrap.grafana_fleet_management_url
    user_id = local.bootstrap.grafana_fleet_management_user_id
  })
}

# The config is only a remotecfg bootstrap; Fleet Management serves the
# pipelines. GCLOUD_RW_API_KEY is set by hand and envs is left out of values, so
# the token stays out of this state.
#
# Host networking lets the served pipelines own their listener ports without a
# matching edit here, and gives constants.hostname the host's name.
resource "truenas_app" "alloy" {
  name        = "alloy"
  catalog_app = "ix-app"
  train       = "stable"

  values = jsonencode({
    command = [
      "run",
      "--storage.path=${local.alloy_storage_path}",
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
        mount_path       = local.alloy_storage_path
        ix_volume_config = { acl_enable = false, dataset_name = "storage_entry" }
      },
    ]
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

# alloy reads its config file only at start, so a new upload redeploys the app.
resource "terraform_data" "alloy_config" {
  triggers_replace = [sha256(local.alloy_config)]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      CONTENT = local.alloy_config
      MODE    = parseint("0644", 8)
      TARGET  = "/mnt/.ix-apps/app_mounts/${truenas_app.alloy.name}/${local.alloy_config_volume}/${local.alloy_config_file}"
      URL     = "https://${local.truenas_host}/_upload"
    }
    command = <<-EOT
      printf '%s' "$CONTENT" |
        curl --fail-with-body --silent --show-error --insecure \
          --header @<(printf 'Authorization: Bearer %s\n' "$TRUENAS_API_KEY") \
          --form-string "data={\"method\":\"filesystem.put\",\"params\":[\"$TARGET\",{\"mode\":$MODE}]}" \
          --form "file=@-" \
          "$URL"
    EOT
  }

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.truenas_app_redeploy.alloy]
    }
  }
}
