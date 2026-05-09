# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# State migration from inline `*.managed[<repo>]` resources (pre-issue-#38)
# to one module instance per repository. Per-instance `moved` blocks are
# required because each instance targets a distinct module instance —
# resource-level moves only work when source and destination addresses
# differ by a single prefix. Safe to delete after one apply absorbs them.

# github_repository
moved {
  from = github_repository.managed["alunduil-chezmoi"]
  to   = module.alunduil_chezmoi.github_repository.this
}
moved {
  from = github_repository.managed["alunduil-infrastructure"]
  to   = module.alunduil_infrastructure.github_repository.this
}
moved {
  from = github_repository.managed["blog.alunduil.com"]
  to   = module.blog_alunduil_com.github_repository.this
}
moved {
  from = github_repository.managed["collection-json.hs"]
  to   = module.collection_json_hs.github_repository.this
}
moved {
  from = github_repository.managed["grafana"]
  to   = module.grafana.github_repository.this
}
moved {
  from = github_repository.managed["murl"]
  to   = module.murl.github_repository.this
}
moved {
  from = github_repository.managed["network-arbitrary"]
  to   = module.network_arbitrary.github_repository.this
}
moved {
  from = github_repository.managed["network-uri-json"]
  to   = module.network_uri_json.github_repository.this
}
moved {
  from = github_repository.managed["siren-json.hs"]
  to   = module.siren_json_hs.github_repository.this
}
moved {
  from = github_repository.managed["woodland-generators"]
  to   = module.woodland_generators.github_repository.this
}
moved {
  from = github_repository.managed["zfs-replicate"]
  to   = module.zfs_replicate.github_repository.this
}

# github_branch_default
moved {
  from = github_branch_default.managed["alunduil-chezmoi"]
  to   = module.alunduil_chezmoi.github_branch_default.this
}
moved {
  from = github_branch_default.managed["alunduil-infrastructure"]
  to   = module.alunduil_infrastructure.github_branch_default.this
}
moved {
  from = github_branch_default.managed["blog.alunduil.com"]
  to   = module.blog_alunduil_com.github_branch_default.this
}
moved {
  from = github_branch_default.managed["collection-json.hs"]
  to   = module.collection_json_hs.github_branch_default.this
}
moved {
  from = github_branch_default.managed["grafana"]
  to   = module.grafana.github_branch_default.this
}
moved {
  from = github_branch_default.managed["murl"]
  to   = module.murl.github_branch_default.this
}
moved {
  from = github_branch_default.managed["network-arbitrary"]
  to   = module.network_arbitrary.github_branch_default.this
}
moved {
  from = github_branch_default.managed["network-uri-json"]
  to   = module.network_uri_json.github_branch_default.this
}
moved {
  from = github_branch_default.managed["siren-json.hs"]
  to   = module.siren_json_hs.github_branch_default.this
}
moved {
  from = github_branch_default.managed["woodland-generators"]
  to   = module.woodland_generators.github_branch_default.this
}
moved {
  from = github_branch_default.managed["zfs-replicate"]
  to   = module.zfs_replicate.github_branch_default.this
}

# github_branch_protection
moved {
  from = github_branch_protection.managed["alunduil-chezmoi"]
  to   = module.alunduil_chezmoi.github_branch_protection.this
}
moved {
  from = github_branch_protection.managed["alunduil-infrastructure"]
  to   = module.alunduil_infrastructure.github_branch_protection.this
}
moved {
  from = github_branch_protection.managed["blog.alunduil.com"]
  to   = module.blog_alunduil_com.github_branch_protection.this
}
moved {
  from = github_branch_protection.managed["collection-json.hs"]
  to   = module.collection_json_hs.github_branch_protection.this
}
moved {
  from = github_branch_protection.managed["grafana"]
  to   = module.grafana.github_branch_protection.this
}
moved {
  from = github_branch_protection.managed["murl"]
  to   = module.murl.github_branch_protection.this
}
moved {
  from = github_branch_protection.managed["network-arbitrary"]
  to   = module.network_arbitrary.github_branch_protection.this
}
moved {
  from = github_branch_protection.managed["network-uri-json"]
  to   = module.network_uri_json.github_branch_protection.this
}
moved {
  from = github_branch_protection.managed["siren-json.hs"]
  to   = module.siren_json_hs.github_branch_protection.this
}
moved {
  from = github_branch_protection.managed["woodland-generators"]
  to   = module.woodland_generators.github_branch_protection.this
}
moved {
  from = github_branch_protection.managed["zfs-replicate"]
  to   = module.zfs_replicate.github_branch_protection.this
}

# github_repository_vulnerability_alerts
moved {
  from = github_repository_vulnerability_alerts.managed["alunduil-chezmoi"]
  to   = module.alunduil_chezmoi.github_repository_vulnerability_alerts.this
}
moved {
  from = github_repository_vulnerability_alerts.managed["alunduil-infrastructure"]
  to   = module.alunduil_infrastructure.github_repository_vulnerability_alerts.this
}
moved {
  from = github_repository_vulnerability_alerts.managed["blog.alunduil.com"]
  to   = module.blog_alunduil_com.github_repository_vulnerability_alerts.this
}
moved {
  from = github_repository_vulnerability_alerts.managed["collection-json.hs"]
  to   = module.collection_json_hs.github_repository_vulnerability_alerts.this
}
moved {
  from = github_repository_vulnerability_alerts.managed["grafana"]
  to   = module.grafana.github_repository_vulnerability_alerts.this
}
moved {
  from = github_repository_vulnerability_alerts.managed["murl"]
  to   = module.murl.github_repository_vulnerability_alerts.this
}
moved {
  from = github_repository_vulnerability_alerts.managed["network-arbitrary"]
  to   = module.network_arbitrary.github_repository_vulnerability_alerts.this
}
moved {
  from = github_repository_vulnerability_alerts.managed["network-uri-json"]
  to   = module.network_uri_json.github_repository_vulnerability_alerts.this
}
moved {
  from = github_repository_vulnerability_alerts.managed["siren-json.hs"]
  to   = module.siren_json_hs.github_repository_vulnerability_alerts.this
}
moved {
  from = github_repository_vulnerability_alerts.managed["woodland-generators"]
  to   = module.woodland_generators.github_repository_vulnerability_alerts.this
}
moved {
  from = github_repository_vulnerability_alerts.managed["zfs-replicate"]
  to   = module.zfs_replicate.github_repository_vulnerability_alerts.this
}

# github_repository_pages — only blog.alunduil.com has pages enabled. The
# destination uses the [0] index because the module declares this resource
# with `count = var.pages != null ? 1 : 0`.
moved {
  from = github_repository_pages.managed["blog.alunduil.com"]
  to   = module.blog_alunduil_com.github_repository_pages.this[0]
}
