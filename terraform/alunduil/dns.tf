# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# alunduil.com is hosted on Cloudflare. Authoritative NS:
#   brenna.ns.cloudflare.com, vick.ns.cloudflare.com
# The zone itself is not Terraform-managed; only its records are.

locals {
  cloudflare_zone_id = "0ee2520bb84646200856ade7817daf2f"
}

resource "cloudflare_dns_record" "moria_a" {
  zone_id = local.cloudflare_zone_id
  name    = "moria.alunduil.com"
  type    = "A"
  content = "85.190.149.100"
  ttl     = 1
  proxied = false
}

# Blog cuts over from the legacy GCS bucket to GitHub Pages. Proxied stays off
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

# d.blog and r.blog still point at the legacy GCS bucket. Imported as-is to
# preserve current state; decide separately whether to repoint or retire.
resource "cloudflare_dns_record" "d_blog_cname" {
  zone_id = local.cloudflare_zone_id
  name    = "d.blog.alunduil.com"
  type    = "CNAME"
  content = "c.storage.googleapis.com"
  ttl     = 1
  proxied = true
}

resource "cloudflare_dns_record" "r_blog_cname" {
  zone_id = local.cloudflare_zone_id
  name    = "r.blog.alunduil.com"
  type    = "CNAME"
  content = "c.storage.googleapis.com"
  ttl     = 1
  proxied = true
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

resource "cloudflare_dns_record" "mx_aspmx" {
  zone_id  = local.cloudflare_zone_id
  name     = "alunduil.com"
  type     = "MX"
  content  = "aspmx.l.google.com"
  ttl      = 1
  priority = 1
}

resource "cloudflare_dns_record" "mx_alt1" {
  zone_id  = local.cloudflare_zone_id
  name     = "alunduil.com"
  type     = "MX"
  content  = "alt1.aspmx.l.google.com"
  ttl      = 1
  priority = 5
}

resource "cloudflare_dns_record" "mx_alt2" {
  zone_id  = local.cloudflare_zone_id
  name     = "alunduil.com"
  type     = "MX"
  content  = "alt2.aspmx.l.google.com"
  ttl      = 1
  priority = 5
}

resource "cloudflare_dns_record" "mx_alt3" {
  zone_id  = local.cloudflare_zone_id
  name     = "alunduil.com"
  type     = "MX"
  content  = "alt3.aspmx.l.google.com"
  ttl      = 1
  priority = 10
}

resource "cloudflare_dns_record" "mx_alt4" {
  zone_id  = local.cloudflare_zone_id
  name     = "alunduil.com"
  type     = "MX"
  content  = "alt4.aspmx.l.google.com"
  ttl      = 1
  priority = 10
}

resource "cloudflare_dns_record" "txt_spf" {
  zone_id = local.cloudflare_zone_id
  name    = "alunduil.com"
  type    = "TXT"
  content = "\"v=spf1 include:_spf.google.com ~all\""
  ttl     = 1
}

resource "cloudflare_dns_record" "txt_dkim_google" {
  zone_id = local.cloudflare_zone_id
  name    = "google._domainkey.alunduil.com"
  type    = "TXT"
  content = "\"v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAhBCA54XCrTJj/WfkFJbxGVX8VWhPb8U4+ThOT1t+A4TXm06YXjscLYqFYVs7smyTeT2flKpW5rj4pFj+fH/rDbfCCiJBkea9O43l2bL4RBxKjnt7apcmnB58c4R4WhjrKOUt+MG4kyj\" \"8Kv+J7GqK0qQuWLRIlz5fZb0a2AxYZCUnxaVeb357secVqGkwmChLrFG4g9Zp662ouHCLBxoKB/x0G2Tg04UllqHPgrrpsQYUIgtFa1OSbFsB3wWNbuuDJpPxjvFZawWHDOtmkBkMANtnxX9yluLRGrhcoaA2g6EI1pydbLFF5YucxRKRn0f/Yzw8IKfT8D3faIU60IaY\" \"zQIDAQAB\"" # pragma: allowlist secret
  ttl     = 1
}

resource "cloudflare_dns_record" "txt_keybase" {
  zone_id = local.cloudflare_zone_id
  name    = "_keybase.alunduil.com"
  type    = "TXT"
  content = "\"keybase-site-verification=KcW7SfZNckcQxOunGDM_ukMY50f3SNovxVDgxAB5pLs\""
  ttl     = 1
}

import {
  to = cloudflare_dns_record.moria_a
  id = "${local.cloudflare_zone_id}/8dcc068d40bf18a52074f83ebc07ba4e"
}

import {
  to = cloudflare_dns_record.blog_cname
  id = "${local.cloudflare_zone_id}/47c444ffbf44a0cd8d3aa9802e7107c8"
}

import {
  to = cloudflare_dns_record.d_blog_cname
  id = "${local.cloudflare_zone_id}/150af659982043ef394caa2f2ad96d2f"
}

import {
  to = cloudflare_dns_record.r_blog_cname
  id = "${local.cloudflare_zone_id}/664a312a21f801007f79697acfcaf657"
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
  to = cloudflare_dns_record.mx_aspmx
  id = "${local.cloudflare_zone_id}/a2cd12b150ebac33d9a9bbe6f13c94ef"
}

import {
  to = cloudflare_dns_record.mx_alt1
  id = "${local.cloudflare_zone_id}/71b5dc25d067bc00baaa407eeb1b187a"
}

import {
  to = cloudflare_dns_record.mx_alt2
  id = "${local.cloudflare_zone_id}/957938764832cdd769a96995cb217407"
}

import {
  to = cloudflare_dns_record.mx_alt3
  id = "${local.cloudflare_zone_id}/93764db0c0fe9e5905559eb5dd93924a"
}

import {
  to = cloudflare_dns_record.mx_alt4
  id = "${local.cloudflare_zone_id}/2854aaab3af29f9d89d949d326385b6a"
}

import {
  to = cloudflare_dns_record.txt_spf
  id = "${local.cloudflare_zone_id}/474b706f81e2c4e34c859e15d7218211"
}

import {
  to = cloudflare_dns_record.txt_dkim_google
  id = "${local.cloudflare_zone_id}/0687ad09a3a875367e76fd002e294df1"
}

import {
  to = cloudflare_dns_record.txt_keybase
  id = "${local.cloudflare_zone_id}/f3408d9fed4eebf7fc2a941449a84c62"
}
