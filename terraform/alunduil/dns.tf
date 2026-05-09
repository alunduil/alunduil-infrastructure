# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# alunduil.com is hosted on Cloudflare. Authoritative NS:
#   brenna.ns.cloudflare.com, vick.ns.cloudflare.com
# The zone itself is not Terraform-managed; only its records are.

locals {
  cloudflare_zone_id = "0ee2520bb84646200856ade7817daf2f"
}

# blog cuts over from the legacy GCS bucket to GitHub Pages. Proxied stays off
# so GitHub can provision a Let's Encrypt cert for the apex CNAME; flip to true
# once the cert is in place if Cloudflare features are wanted in front.
resource "cloudflare_dns_record" "blog_cname" {
  zone_id = local.cloudflare_zone_id
  name    = "blog.alunduil.com"
  type    = "CNAME"
  content = "alunduil.github.io"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "home_cname" {
  zone_id = local.cloudflare_zone_id
  name    = "home.alunduil.com"
  type    = "CNAME"
  content = "alunduil.tplinkdns.com"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "plex_cname" {
  zone_id = local.cloudflare_zone_id
  name    = "plex.alunduil.com"
  type    = "CNAME"
  content = "home.alunduil.com"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "txt_keybase" {
  zone_id = local.cloudflare_zone_id
  name    = "_keybase.alunduil.com"
  type    = "TXT"
  content = "\"keybase-site-verification=KcW7SfZNckcQxOunGDM_ukMY50f3SNovxVDgxAB5pLs\""
  ttl     = 1
}

import {
  to = cloudflare_dns_record.blog_cname
  id = "${local.cloudflare_zone_id}/47c444ffbf44a0cd8d3aa9802e7107c8"
}

import {
  to = cloudflare_dns_record.home_cname
  id = "${local.cloudflare_zone_id}/506de57cc5722cdf3db23840786d47cd"
}

import {
  to = cloudflare_dns_record.plex_cname
  id = "${local.cloudflare_zone_id}/e2dbf6462bacfbdd1e2897bfb261d01c"
}

import {
  to = cloudflare_dns_record.txt_keybase
  id = "${local.cloudflare_zone_id}/f3408d9fed4eebf7fc2a941449a84c62"
}

# DS values for the Squarespace registrar are exposed via output.alunduil_com_ds.
resource "cloudflare_zone_dnssec" "alunduil_com" {
  zone_id = local.cloudflare_zone_id
  status  = "active"
}
