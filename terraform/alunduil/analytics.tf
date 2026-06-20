# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# blog.alunduil.com is gray-clouded (GitHub Pages origin, DNS-only through
# Cloudflare), so Cloudflare can't inject the beacon snippet. auto_install
# stays off; the blog hand-injects the beacon from its source using the
# site_token exposed via output.blog_web_analytics_token.
resource "cloudflare_web_analytics_site" "blog_alunduil_com" {
  account_id   = cloudflare_zone.alunduil_com.account.id
  host         = "blog.alunduil.com"
  auto_install = false
}
