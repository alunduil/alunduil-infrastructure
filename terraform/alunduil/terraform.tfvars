# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

repositories = {
  "alunduil-chezmoi" = {
    classification = "default"
  }

  "alunduil-infrastructure" = {
    classification = "default"
  }

  "blog.alunduil.com" = {
    description    = "Personal blog at blog.alunduil.com"
    homepage_url   = "https://blog.alunduil.com"
    classification = "default"
    topics         = ["blog", "github-pages"]
    pages = {
      cname          = "blog.alunduil.com"
      build_type     = "workflow"
      https_enforced = true
    }
  }

  "collection-json.hs" = {
    description    = "Collection+JSON Tools for Haskell"
    classification = "default"
    topics         = ["haskell-library", "collection-json", "haskell", "hypermedia"]
  }

  "grafana" = {
    classification = "default"
  }

  "murl" = {
    description    = "Small Toy URL Shortener in Haskell"
    classification = "default"
    default_branch = "master"
  }

  "network-arbitrary" = {
    description    = "Arbitrary Instances for Network Types"
    classification = "default"
    default_branch = "master"
  }

  "network-uri-json" = {
    description    = "FromJSON and ToJSON Instances for Network.URI"
    classification = "default"
    topics         = ["haskell-library", "haskell", "json", "network-uri", "uri"]
    default_branch = "develop"
  }

  "siren-json.hs" = {
    description    = "Siren+JSON Tools for Haskell"
    classification = "default"
    topics         = ["haskell-library", "haskell", "siren-json", "hypermedia"]
  }

  "woodland-generators" = {
    description     = "A CLI tool for generating resources for Root: The Tabletop RPG."
    classification  = "default"
    topics          = ["cli", "generator", "root", "rpg", "tabletop"]
    has_discussions = true
    default_branch  = "master"
    template = {
      owner      = "League-of-Foundry-Developers"
      repository = "FoundryVTT-Module-Template"
    }
  }

  "zfs-replicate" = {
    description    = "ZFS Replication"
    classification = "default"
    topics         = ["zfs", "replication", "snapshots"]
    default_branch = "master"
  }

}
