<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the blog.alunduil.com Web Analytics site

Cloudflare Web Analytics lives outside Terraform. The only token
permission that authorizes `POST /rum/site_info` is account-wide
`Account Settings Write`, far broader than the deployer token's
zone-scoped grants — so the site is created by hand instead of widening
that token.

1. At <https://dash.cloudflare.com> open **Analytics & Logs** → **Web
   Analytics** → **Add a site**. Enter hostname `blog.alunduil.com`.
2. Turn **automatic setup off**. The blog is gray-clouded (GitHub Pages
   origin, DNS-only through Cloudflare), so Cloudflare can't inject the
   beacon — the blog hand-injects it from source.
3. Copy the site's beacon token (the `token` value in the snippet
   Cloudflare shows). It ships in client-side JS, so it's public, not a
   secret.
4. Paste it into blog.alunduil.com's `src/config.ts`
   `cloudflareWebAnalyticsToken` and commit. The commit triggers the
   `pages.yml` deploy, so the beacon goes live without a manual rebuild.

The token is write-once and changes only if the site is recreated, so
no ongoing sync is needed.
