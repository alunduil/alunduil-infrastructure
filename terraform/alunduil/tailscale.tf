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
resource "tailscale_dns_nameservers" "global" {
  nameservers = ["8.8.8.8"]
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

# devices_key_duration_days stops at the exit nodes: each carries a per-device
# key_expiry_disabled flag, set outside Terraform. A tag won't replace it —
# tagging disables expiry only at a device's first authentication under one.
resource "tailscale_tailnet_settings" "this" {
  acls_externally_managed_on     = false
  devices_approval_on            = true
  devices_auto_updates_on        = false
  devices_key_duration_days      = 180
  https_enabled                  = false
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
