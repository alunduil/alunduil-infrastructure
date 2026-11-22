# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

locals {
  # TS_SERVE_CONFIG has to point inside this mount. containerboot treats a
  # missing serve file as no serve config and logs no error.
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
        { name = "TS_SERVE_CONFIG", value = "${local.tailscale_config_directory}/serve.json" },
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

# The provider has no file resource, so this uploads serve.json through the
# API's filesystem.put. The upload runs as a TrueNAS job, and curl sees only
# that the job started, not that it finished.
resource "terraform_data" "tailscale_serve_config" {
  triggers_replace = [filesha256("${path.module}/tailscale/serve.json")]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      SOURCE = abspath("${path.module}/tailscale/serve.json")
      TARGET = "/mnt/.ix-apps/app_mounts/${truenas_app.tailscale.name}/${local.tailscale_config_volume}/serve.json"
      URL    = "https://${local.truenas_host}/_upload"
    }
    # The header file keeps the key out of the process list. 420 is 0644.
    command = <<-EOT
      curl --fail-with-body --silent --show-error --insecure \
        --header @<(printf 'Authorization: Bearer %s\n' "$TRUENAS_API_KEY") \
        --form-string "data={\"method\":\"filesystem.put\",\"params\":[\"$TARGET\",{\"mode\":420}]}" \
        --form "file=@$SOURCE" \
        "$URL"
    EOT
  }
}
