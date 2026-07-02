# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# alunduil.com is hosted on Cloudflare. Authoritative NS:
#   brenna.ns.cloudflare.com, vick.ns.cloudflare.com
# The zone, a security-relevant subset of zone settings, and every record
# except home.alunduil.com are Terraform-managed. Settings not declared
# below track Cloudflare's defaults — add a `cloudflare_zone_setting`
# resource only when drift detection on a specific one is wanted.

# Recreating the zone mints a new Cloudflare NS pair, forcing a registrar
# update and propagation outage. `prevent_destroy` blocks `terraform
# destroy` from removing it; deletion has to go through a code change
# first.
resource "cloudflare_zone" "alunduil_com" {
  account = {
    id = "76626ec3f004e86f1a4d85faca9ac3a2" # pragma: allowlist secret
  }
  name = "alunduil.com"
  type = "full"

  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = cloudflare_zone.alunduil_com
  id = "0ee2520bb84646200856ade7817daf2f" # pragma: allowlist secret
}

# Zone settings affect proxied records at the edge. All alunduil.com
# records currently have `proxied = false`, so these are pre-staged for
# any future proxy flip rather than gating today's traffic.
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = cloudflare_zone.alunduil_com.id
  setting_id = "ssl"
  value      = "strict"
}

resource "cloudflare_zone_setting" "min_tls_version" {
  zone_id    = cloudflare_zone.alunduil_com.id
  setting_id = "min_tls_version"
  value      = "1.2"
}

resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = cloudflare_zone.alunduil_com.id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "automatic_https_rewrites" {
  zone_id    = cloudflare_zone.alunduil_com.id
  setting_id = "automatic_https_rewrites"
  value      = "on"
}

import {
  to = cloudflare_zone_setting.ssl
  id = "${cloudflare_zone.alunduil_com.id}/ssl"
}

import {
  to = cloudflare_zone_setting.min_tls_version
  id = "${cloudflare_zone.alunduil_com.id}/min_tls_version"
}

import {
  to = cloudflare_zone_setting.always_use_https
  id = "${cloudflare_zone.alunduil_com.id}/always_use_https"
}

import {
  to = cloudflare_zone_setting.automatic_https_rewrites
  id = "${cloudflare_zone.alunduil_com.id}/automatic_https_rewrites"
}

# blog cuts over from the legacy GCS bucket to GitHub Pages. Proxied stays off
# so GitHub can provision a Let's Encrypt cert for the apex CNAME; flip to true
# once the cert is in place if Cloudflare features are wanted in front.
resource "cloudflare_dns_record" "blog_cname" {
  zone_id = cloudflare_zone.alunduil_com.id
  name    = "blog.alunduil.com"
  type    = "CNAME"
  content = "alunduil.github.io"
  ttl     = 1
  proxied = false
}

# home.alunduil.com is intentionally absent: a Cloudflare-native DDNS client
# on TrueNAS owns its A record, writing the dynamic home IP straight into
# Cloudflare. A Terraform-managed record would fight that client on every
# plan. plex_cname below still points at it. This replaces a CNAME to
# alunduil.tplinkdns.com, whose flaky TP-Link nameservers dropped ~25% of
# queries and tripped UptimeRobot's DNS-resolution checks.

resource "cloudflare_dns_record" "plex_cname" {
  zone_id = cloudflare_zone.alunduil_com.id
  name    = "plex.alunduil.com"
  type    = "CNAME"
  content = "home.alunduil.com"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "txt_keybase" {
  zone_id = cloudflare_zone.alunduil_com.id
  name    = "_keybase.alunduil.com"
  type    = "TXT"
  content = "\"keybase-site-verification=KcW7SfZNckcQxOunGDM_ukMY50f3SNovxVDgxAB5pLs\""
  ttl     = 1
}

# Bluesky handle verification: proves alunduil.com controls the AT Protocol
# DID, letting @alunduil.bsky.social switch its handle to @alunduil.com.
resource "cloudflare_dns_record" "txt_atproto" {
  zone_id = cloudflare_zone.alunduil_com.id
  name    = "_atproto.alunduil.com"
  type    = "TXT"
  content = "did=did:plc:urcrp6xgybniubantb6asetr"
  ttl     = 1
}

# DS values for the Squarespace registrar are exposed via output.alunduil_com_ds.
resource "cloudflare_zone_dnssec" "alunduil_com" {
  zone_id = cloudflare_zone.alunduil_com.id
  status  = "active"
}
