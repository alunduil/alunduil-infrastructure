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

  # Keying on the MagicDNS label keeps the opaque node IDs out of the
  # configuration.
  tailscale_devices_by_name = {
    for device in data.tailscale_devices.all.devices :
    split(".", device.name)[0] => device
  }
}

# The factory-default policy file: a grant accepting every connection, and
# Tailscale SSH to a member's own devices in check mode.
#
# The policy lives in its own file, byte for byte as the tailnet holds it.
# The provider compares the attribute as a string, so a semantically equal
# rewrite still counts as a change — and applying one would strip the
# commented-out examples Tailscale ships in the default file, which are the
# reference for writing the grants that replace it.
#
# overwrite_existing_content stays unset. If the import ever fails to take,
# Terraform refuses to create over a policy file it doesn't own rather than
# clobbering it.
resource "tailscale_acl" "tailnet" {
  acl = file("${path.module}/tailscale-acl.hujson")
}

import {
  to = tailscale_acl.tailnet
  id = "acl"
}

# Google Public DNS. A client reports more resolvers than this; the tailnet
# publishes the one.
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

# No tailscale_dns_search_paths: the tailnet hands out no search domain beyond
# its own MagicDNS suffix.

# One resource carries every tailnet-wide toggle the admin console's Settings
# pages expose, device approval and key expiry among them. acls_external_link
# and users_role_allowed_to_join_external_tailnet are absent because the
# tailnet holds no value for either.
resource "tailscale_tailnet_settings" "this" {
  acls_externally_managed_on     = false
  devices_approval_on            = false
  devices_auto_updates_on        = false
  devices_key_duration_days      = 0
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
