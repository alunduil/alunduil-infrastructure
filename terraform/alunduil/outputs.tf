# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# DS fields for manual publication at the Squarespace registrar (not TF-managed).
output "alunduil_com_ds" {
  value = {
    key_tag     = cloudflare_zone_dnssec.alunduil_com.key_tag
    algorithm   = cloudflare_zone_dnssec.alunduil_com.algorithm
    digest_type = cloudflare_zone_dnssec.alunduil_com.digest_type
    digest      = cloudflare_zone_dnssec.alunduil_com.digest
  }
  description = "DS record fields to publish at the Squarespace registrar for alunduil.com"
}

# Public beacon token (shipped in the blog's client-side JS), not a secret.
output "blog_web_analytics_token" {
  value       = cloudflare_web_analytics_site.blog_alunduil_com.site_token
  description = "Web Analytics beacon token for blog.alunduil.com (paste into blog.alunduil.com src/config.ts cloudflareWebAnalyticsToken)"
}
