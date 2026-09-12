# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Every value in this file is the tailnet's live setting rather than a chosen
# one. Importing the tailnet as it stands makes each later hardening step a
# diff a reviewer can read, instead of a rewrite with no baseline to compare
# against.
#
# Two parts of the tailnet stay out. No device carries a tag, so
# tailscale_device_tags has nothing to hold until tagOwners exists in the
# policy file. And auth keys, though importable by key id, lose their key
# material on import — Terraform would own credentials it cannot reproduce, so
# the keys worth keeping are better created here than adopted.

data "tailscale_devices" "all" {}

locals {
  # Enabling a route and advertising it are separate acts: the device
  # advertises, the tailnet enables. This resource owns the enabled half, and
  # it owns all of it — a route enabled in the admin console but missing here
  # gets disabled on the next apply. 0.0.0.0/0 and ::/0 are what an exit node
  # advertises.
  tailscale_enabled_routes = {
    "truenas-scale" = ["192.168.68.0/22", "0.0.0.0/0", "::/0"]
    "nanopi-neo3"   = ["0.0.0.0/0", "::/0"]
  }

  # Keying on the MagicDNS label keeps the node IDs, which are opaque and
  # change when a device re-registers, out of the configuration.
  tailscale_devices_by_name = {
    for device in data.tailscale_devices.all.devices :
    split(".", device.name)[0] => device
  }
}

# The factory-default policy file: accept every connection, and allow Tailscale
# SSH to a member's own devices in check mode.
#
# overwrite_existing_content stays unset. If the import ever fails to take,
# Terraform refuses to create over a policy file it doesn't own rather than
# clobbering it.
resource "tailscale_acl" "tailnet" {
  acl = jsonencode({
    acls = [
      {
        action = "accept"
        src    = ["*"]
        dst    = ["*:*"]
      },
    ]
    ssh = [
      {
        action = "check"
        src    = ["autogroup:member"]
        dst    = ["autogroup:self"]
        users  = ["autogroup:nonroot", "root"]
      },
    ]
  })
}

import {
  to = tailscale_acl.tailnet
  id = "acl"
}

# Google Public DNS, v4 and v6.
resource "tailscale_dns_nameservers" "global" {
  nameservers = [
    "8.8.8.8",
    "8.8.4.4",
    "2001:4860:4860::8888",
    "2001:4860:4860::8844",
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

# No tailscale_dns_search_paths: the only search domain the tailnet hands out
# is its own MagicDNS suffix, which MagicDNS supplies rather than this list.

# One resource carries every tailnet-wide toggle the admin console's Settings
# pages expose, device approval and key expiry among them. Each attribute is
# optional, but all of them are declared: an omitted one reads as null and the
# provider would clear the setting behind it.
resource "tailscale_tailnet_settings" "this" {
  acls_externally_managed_on                  = false
  devices_approval_on                         = false
  devices_auto_updates_on                     = false
  devices_key_duration_days                   = 180
  https_enabled                               = false
  network_flow_logging_on                     = false
  posture_identity_collection_on              = false
  regional_routing_on                         = false
  users_approval_on                           = false
  users_role_allowed_to_join_external_tailnet = "member"
}

import {
  to = tailscale_tailnet_settings.this
  id = "tailnet_settings"
}

resource "tailscale_device_subnet_routes" "routers" {
  for_each = local.tailscale_enabled_routes

  device_id = local.tailscale_devices_by_name[each.key].node_id
  routes    = each.value
}

import {
  for_each = local.tailscale_enabled_routes

  to = tailscale_device_subnet_routes.routers[each.key]
  id = local.tailscale_devices_by_name[each.key].node_id
}
