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
