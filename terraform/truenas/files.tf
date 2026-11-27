# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Each file lands in an app's ix volume. The volume exists only after the app's
# update creates it, so each target references its app to upload after that
# update.
locals {
  truenas_files = {
    tailscale_serve = {
      content = file("${path.module}/tailscale/${local.tailscale_serve_file}")
      target  = "/mnt/.ix-apps/app_mounts/${truenas_app.tailscale.name}/${local.tailscale_config_volume}/${local.tailscale_serve_file}"
    }

    # alloy crash-loops until this lands, and reads it only at start.
    alloy_config = {
      content = local.alloy_config
      target  = "/mnt/.ix-apps/app_mounts/${truenas_app.alloy.name}/${local.alloy_config_volume}/${local.alloy_config_file}"
    }
  }
}

moved {
  from = terraform_data.tailscale_serve_config
  to   = terraform_data.file["tailscale_serve"]
}

# The provider has no file resource. The upload runs as a TrueNAS job, and curl
# sees only that the job started, not that it finished.
action "truenas_app_redeploy" "alloy" {
  config {
    app_name = truenas_app.alloy.name
  }
}

resource "terraform_data" "file" {
  for_each = local.truenas_files

  triggers_replace = [sha256(each.value.content)]

  # A changed file replaces this resource, so after_create follows each upload.
  lifecycle {
    action_trigger {
      events    = [after_create]
      condition = each.key == "alloy_config"
      actions   = [action.truenas_app_redeploy.alloy]
    }
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      CONTENT = each.value.content
      MODE    = parseint("0644", 8)
      TARGET  = each.value.target
      URL     = "https://${local.truenas_host}/_upload"
    }
    # Reading the header from a file descriptor keeps the key out of the
    # process list.
    command = <<-EOT
      printf '%s' "$CONTENT" | curl --fail-with-body --silent --show-error --insecure \
        --header @<(printf 'Authorization: Bearer %s\n' "$TRUENAS_API_KEY") \
        --form-string "data={\"method\":\"filesystem.put\",\"params\":[\"$TARGET\",{\"mode\":$MODE}]}" \
        --form "file=@-;filename=$(basename "$TARGET")" \
        "$URL"
    EOT
  }
}
