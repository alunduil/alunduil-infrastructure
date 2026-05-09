# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

module "alunduil_chezmoi" {
  source = "../modules/github_repository"
  name   = "alunduil-chezmoi"
}

module "alunduil_infrastructure" {
  source = "../modules/github_repository"
  name   = "alunduil-infrastructure"
}

module "blog_alunduil_com" {
  source       = "../modules/github_repository"
  name         = "blog.alunduil.com"
  description  = "Personal blog at blog.alunduil.com"
  homepage_url = "https://blog.alunduil.com"
  topics       = ["blog", "github-pages"]
  pages = {
    cname      = "blog.alunduil.com"
    build_type = "workflow"
  }
}

module "collection_json_hs" {
  source      = "../modules/github_repository"
  name        = "collection-json.hs"
  description = "Collection+JSON Tools for Haskell"
  topics      = ["haskell-library", "collection-json", "haskell", "hypermedia"]
}

module "grafana" {
  source = "../modules/github_repository"
  name   = "grafana"
}

module "murl" {
  source         = "../modules/github_repository"
  name           = "murl"
  description    = "Small Toy URL Shortener in Haskell"
  default_branch = "master"
}

module "network_arbitrary" {
  source         = "../modules/github_repository"
  name           = "network-arbitrary"
  description    = "Arbitrary Instances for Network Types"
  default_branch = "master"
}

module "network_uri_json" {
  source         = "../modules/github_repository"
  name           = "network-uri-json"
  description    = "FromJSON and ToJSON Instances for Network.URI"
  topics         = ["haskell-library", "haskell", "json", "network-uri", "uri"]
  default_branch = "develop"
}

module "siren_json_hs" {
  source      = "../modules/github_repository"
  name        = "siren-json.hs"
  description = "Siren+JSON Tools for Haskell"
  topics      = ["haskell-library", "haskell", "siren-json", "hypermedia"]
}

module "woodland_generators" {
  source          = "../modules/github_repository"
  name            = "woodland-generators"
  description     = "A CLI tool for generating resources for Root: The Tabletop RPG."
  topics          = ["cli", "generator", "root", "rpg", "tabletop"]
  has_discussions = true
  default_branch  = "master"
  template = {
    owner      = "League-of-Foundry-Developers"
    repository = "FoundryVTT-Module-Template"
  }
}

module "zfs_replicate" {
  source         = "../modules/github_repository"
  name           = "zfs-replicate"
  description    = "ZFS Replication"
  topics         = ["zfs", "replication", "snapshots"]
  default_branch = "master"
}
