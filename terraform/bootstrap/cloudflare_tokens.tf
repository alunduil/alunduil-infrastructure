# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Deployer Cloudflare API tokens minted by terraform so CI never needs an
# operator-pasted token. Stored as sensitive outputs and surfaced to the
# secrets script via `terraform output -raw`.
#
# Permission groups are looked up by name (URL-encoded) rather than hardcoded
# by ID; the IDs are stable but the lookup is self-documenting.

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
  # alunduil.com zone resource scope. Zone id is the same one imported in
  # terraform/alunduil/dns.tf for cloudflare_zone.alunduil_com.
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
