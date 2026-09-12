# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Auth keys are deliberately unmanaged. Importing one drops its key material,
# leaving Terraform owning a credential it cannot reproduce.

# Keep the policy file byte-identical to the tailnet's copy. The provider
# compares acl as a string, so a semantically equal rewrite plans as a change
# and applies as a rewrite of the live policy, comments included.
#
# Leave overwrite_existing_content unset. It allows a create over a policy file
# Terraform doesn't own, which is what a failed import would attempt.
resource "tailscale_acl" "tailnet" {
  acl = file("${path.module}/tailscale-acl.hujson")
}

import {
  to = tailscale_acl.tailnet
  id = "acl"
}

# A client's resolver list shows more than this — the rest are not the
# tailnet's.
#
# Quad9 refuses to resolve domains on its malicious-domain feeds, so the block
# lands at the resolver for every tailnet client. All four addresses are the
# same blocking-and-DNSSEC service — primary and secondary over both families.
#
# Tailscale does not guarantee query order and may take the quickest response.
# A resolver from another provider added here answers some fraction of queries
# under its own policy rather than acting as a fallback.
resource "tailscale_dns_nameservers" "global" {
  nameservers = [
    "9.9.9.9",
    "149.112.112.112",
    "2620:fe::fe",
    "2620:fe::9",
  ]
}

import {
  to = tailscale_dns_nameservers.global
  id = "dns_nameservers"
}

resource "tailscale_dns_preferences" "magic_dns" {
  magic_dns = true
}

import {
  to = tailscale_dns_preferences.magic_dns
  id = "dns_preferences"
}

resource "tailscale_tailnet_settings" "this" {
  acls_externally_managed_on     = false
  devices_approval_on            = false
  devices_auto_updates_on        = false
  devices_key_duration_days      = 0
  https_enabled                  = true
  network_flow_logging_on        = false
  posture_identity_collection_on = false
  regional_routing_on            = false
  users_approval_on              = false
}

import {
  to = tailscale_tailnet_settings.this
  id = "tailnet_settings"
}

data "tailscale_devices" "all" {}

locals {
  tailscale_exit_node_routes = ["0.0.0.0/0", "::/0"]

  # Advertising a route and enabling it are separate acts: the device
  # advertises, the tailnet enables. This map is the whole enabled set — a
  # route enabled in the admin console but absent here gets disabled on the
  # next apply.
  tailscale_enabled_routes = {
    "truenas-scale" = concat(["192.168.68.0/22"], local.tailscale_exit_node_routes)
    "nanopi-neo3"   = local.tailscale_exit_node_routes
  }

  tailscale_node_ids = {
    for device in data.tailscale_devices.all.devices :
    split(".", device.name)[0] => device.node_id
  }
}

resource "tailscale_device_subnet_routes" "routers" {
  for_each = local.tailscale_enabled_routes

  device_id = local.tailscale_node_ids[each.key]
  routes    = each.value
}

import {
  for_each = local.tailscale_enabled_routes

  to = tailscale_device_subnet_routes.routers[each.key]
  id = local.tailscale_node_ids[each.key]
}
