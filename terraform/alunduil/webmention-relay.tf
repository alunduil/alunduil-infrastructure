# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# blog.alunduil.com renders webmentions at build time, so its display freezes
# between builds. webmention.io can call back on every new mention, but it POSTs
# the shared secret in the JSON body with no auth headers, so it can't reach
# GitHub's dispatch API itself. This relay holds the GitHub credential and turns
# a validated callback into the `repository_dispatch` that rebuilds the blog,
# retiring that repo's polling cron.

locals {
  webmention_relay_source = "${path.module}/webmention-relay/worker.js"
}

resource "cloudflare_workers_script" "webmention_relay" {
  account_id  = cloudflare_zone.alunduil_com.account.id
  script_name = "webmention-relay"

  # content_file keeps the script body out of this layer's state; the hash is
  # what tells Terraform the source changed.
  content_file   = local.webmention_relay_source
  content_sha256 = filesha256(local.webmention_relay_source)
  main_module    = basename(local.webmention_relay_source)

  compatibility_date = "2026-09-01"

  # Both secrets are set by hand, per
  # docs/how-to/configure-webmention-relay.md, so neither the GitHub token nor
  # the shared secret reaches this layer's state — which both deployer service
  # accounts can read out of alunduil-tfstate. Naming the type here preserves
  # them across every re-upload Terraform performs.
  keep_bindings = ["secret_text"]
}

# Attaching the domain creates webmention.alunduil.com and its certificate; no
# cloudflare_dns_record declares it.
resource "cloudflare_workers_custom_domain" "webmention_relay" {
  account_id = cloudflare_zone.alunduil_com.account.id
  hostname   = "webmention.alunduil.com"
  service    = cloudflare_workers_script.webmention_relay.script_name
  zone_id    = cloudflare_zone.alunduil_com.id
  zone_name  = cloudflare_zone.alunduil_com.name
}
