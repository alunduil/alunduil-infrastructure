# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

data "cloudflare_api_token_permission_groups_list" "zone_read" {
  name  = "Zone%20Read"
  scope = "com.cloudflare.api.account.zone"
}

data "cloudflare_api_token_permission_groups_list" "dns_read" {
  name  = "DNS%20Read"
  scope = "com.cloudflare.api.account.zone"
}

data "cloudflare_api_token_permission_groups_list" "dns_write" {
  name  = "DNS%20Write"
  scope = "com.cloudflare.api.account.zone"
}

data "cloudflare_api_token_permission_groups_list" "zone_settings_read" {
  name  = "Zone%20Settings%20Read"
  scope = "com.cloudflare.api.account.zone"
}

data "cloudflare_api_token_permission_groups_list" "zone_settings_write" {
  name  = "Zone%20Settings%20Write"
  scope = "com.cloudflare.api.account.zone"
}

locals {
  alunduil_com_zone_resource = jsonencode({
    "com.cloudflare.api.account.zone.0ee2520bb84646200856ade7817daf2f" = "*" # pragma: allowlist secret
  })
}

resource "cloudflare_api_token" "deployer_ro" {
  name = "alunduil-infrastructure deployer (RO)"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = data.cloudflare_api_token_permission_groups_list.zone_read.result[0].id },
      { id = data.cloudflare_api_token_permission_groups_list.dns_read.result[0].id },
      { id = data.cloudflare_api_token_permission_groups_list.zone_settings_read.result[0].id },
    ]
    resources = local.alunduil_com_zone_resource
  }]
}

resource "cloudflare_api_token" "deployer_rw" {
  name = "alunduil-infrastructure deployer (RW)"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = data.cloudflare_api_token_permission_groups_list.zone_read.result[0].id },
      { id = data.cloudflare_api_token_permission_groups_list.dns_write.result[0].id },
      { id = data.cloudflare_api_token_permission_groups_list.zone_settings_write.result[0].id },
    ]
    resources = local.alunduil_com_zone_resource
  }]
}
