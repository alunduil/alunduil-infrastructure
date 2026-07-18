# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

module "alunduil_chezmoi" {
  source      = "../modules/github_repository"
  name        = "alunduil-chezmoi"
  description = "Personal chezmoi-managed dotfiles and host config: bootstrap a fresh host from bare OS to a working setup in one command."
  topics      = ["chezmoi", "dotfiles", "debian", "crostini", "claude-code"]
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
  required_status_checks = {
    contexts = ["build"]
  }
  pages = {
    cname          = "blog.alunduil.com"
    build_type     = "workflow"
    https_enforced = true
  }
}

module "collection_json_hs" {
  source      = "../modules/github_repository"
  name        = "collection-json.hs"
  description = "Collection+JSON Tools for Haskell"
  topics      = ["haskell-library", "collection-json", "haskell", "hypermedia"]
  # Deployment environment for Hackage releases.
  environments = ["hackage"]
}

module "git_worktree_poi" {
  source      = "../modules/github_repository"
  name        = "git-worktree-poi"
  description = "Prune git worktrees whose branch has merged or whose upstream is gone, and report what's left in a gh-poi-style summary. Reach for it when a worktree-per-branch workflow leaves stale checkouts behind; run it by hand or on a systemd timer."
  topics      = ["cli", "rust", "git", "git-worktree", "claude-code"]
}

# git-worktree-poi was created out-of-band with a user token: the CI GitHub App
# cannot POST /user/repos (403 Resource not accessible by integration), so
# Terraform adopts the existing repository here rather than creating it. The
# default branch, ruleset, and vulnerability alerts are created on apply, which
# the App can do against an existing repo. Remove once applied. The import lives
# in the root module beside its target because import blocks are not allowed in
# child modules.
import {
  to = module.git_worktree_poi.github_repository.this
  id = "git-worktree-poi"
}

module "network_arbitrary" {
  source         = "../modules/github_repository"
  name           = "network-arbitrary"
  description    = "Arbitrary Instances for Network Types"
  default_branch = "master"
}

module "projects_v2_sync" {
  source      = "../modules/github_repository"
  name        = "projects-v2-sync"
  description = "Mirror issues and PRs onto a GitHub Projects v2 board from a declarative in/out spec"
  topics      = ["github-actions", "github-projects", "projects-v2", "typescript"]
}

# projects-v2-sync was created out-of-band with a user token: the CI GitHub App
# cannot POST /user/repos, so Terraform adopts the existing repository here
# rather than creating it. Remove once applied.
import {
  to = module.projects_v2_sync.github_repository.this
  id = "projects-v2-sync"
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

module "zellij_claude_pair" {
  source      = "../modules/github_repository"
  name        = "zellij-claude-pair"
  description = "Zellij plugin for the Claude Code pairing workflow: in-session repo picker and branch/PR status widgets plus worktree session orchestration."
  topics      = ["zellij", "zellij-plugin", "claude-code", "rust", "wasm"]
}

# zellij-claude-pair was created out-of-band with a user token: the CI GitHub
# App cannot POST /user/repos (403 Resource not accessible by integration), so
# Terraform adopts the existing repository here rather than creating it. The
# default branch, ruleset, and vulnerability alerts are created on apply, which
# the App can do against an existing repo. Remove once applied. The import lives
# in the root module beside its target because import blocks are not allowed in
# child modules.
import {
  to = module.zellij_claude_pair.github_repository.this
  id = "zellij-claude-pair"
}

module "zfs_replicate" {
  source         = "../modules/github_repository"
  name           = "zfs-replicate"
  description    = "ZFS Replication"
  topics         = ["zfs", "replication", "snapshots"]
  default_branch = "master"
}

# These three repos already had a hand-created ruleset named "default" before
# the baseline module introduced one, so the first apply hit GitHub's
# "Name must be unique" (422) instead of creating. Adopt the existing rulesets
# into state so apply reconciles them. Remove once applied.
import {
  to = module.alunduil_chezmoi.github_repository_ruleset.default_branch
  id = "alunduil-chezmoi:15615310"
}

import {
  to = module.alunduil_infrastructure.github_repository_ruleset.default_branch
  id = "alunduil-infrastructure:15541031"
}

import {
  to = module.woodland_generators.github_repository_ruleset.default_branch
  id = "woodland-generators:6845434"
}
