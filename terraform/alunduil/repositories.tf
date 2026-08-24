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
  # sync-project reads GH_PROJECT_SYNC_TOKEN from this environment; the
  # branch policy pins the token to main so a workflow_dispatch from an
  # arbitrary branch can't reach it. Token injected out of band.
  environments = {
    "project-sync" = { deployment_branches = ["main"] }
  }
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
  environments = { hackage = {} }
}

module "git_worktree_poi" {
  source      = "../modules/github_repository"
  name        = "git-worktree-poi"
  description = "Prune git worktrees whose branch has merged or whose upstream is gone, and report what's left in a gh-poi-style summary. Reach for it when a worktree-per-branch workflow leaves stale checkouts behind; run it by hand or on a systemd timer."
  topics      = ["cli", "rust", "git", "git-worktree", "claude-code"]
}

module "network_arbitrary" {
  source       = "../modules/github_repository"
  name         = "network-arbitrary"
  description  = "Arbitrary Instances for Network Types"
  topics       = ["haskell-library", "haskell", "network", "quickcheck"]
  environments = { hackage = {} }
}

module "projects_v2_sync" {
  source      = "../modules/github_repository"
  name        = "projects-v2-sync"
  description = "Mirror issues and PRs onto a GitHub Projects v2 board from a declarative in/out spec"
  topics      = ["github-actions", "github-projects", "projects-v2", "typescript"]
}

module "siren_json_hs" {
  source      = "../modules/github_repository"
  name        = "siren-json.hs"
  description = "Siren+JSON Tools for Haskell"
  topics      = ["haskell-library", "haskell", "siren-json", "hypermedia"]
}

module "woodland_generators" {
  source      = "../modules/github_repository"
  name        = "woodland-generators"
  description = "Foundry VTT module for generating Root: The Tabletop RPG content inside a live world."
  # Both Foundry spellings are carried deliberately: the upstream
  # League-of-Foundry-Developers template tags itself foundry-vtt *and*
  # foundryvtt, and neither dominates enough to drop.
  topics = [
    "foundry-vtt",
    "foundryvtt",
    "foundryvtt-module",
    "root-rpg",
    "rpg",
    "ttrpg",
    "tabletop",
    "generator",
    "typescript",
  ]
  # Deviates from the baseline (discussions off). The repo sets
  # blank_issues_enabled: false and routes every non-bug, non-feature path to a
  # Discussions category from .github/ISSUE_TEMPLATE/config.yml, so disabling
  # this leaves help-seekers with nowhere to land.
  has_discussions = true
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

module "zfs_replicate" {
  source         = "../modules/github_repository"
  name           = "zfs-replicate"
  description    = "Replicate ZFS snapshots to a remote host over SSH (Python CLI; replication only — it doesn't create snapshots)."
  homepage_url   = "https://pypi.org/project/zfs-replicate/"
  topics         = ["zfs", "replication", "snapshots"]
  default_branch = "master"
  # .github/CODEOWNERS assigns every path to @alunduil, so this gates every
  # non-owner pull request, Renovate's included.
  require_code_owner_review = true
  required_status_checks = {
    contexts = ["Validate PR title"]
    # The check reads only the PR title, so it can't go stale against the
    # base branch.
    strict = false
  }
  # PyPI pins the Trusted Publisher it accepts to repo + workflow +
  # environment, so the publish job has to run in this one. Approval lands
  # before the credential is issued. No deployment branch policy: the release
  # workflow runs from a tag ref, which such a policy would refuse.
  environments = {
    pypi = { reviewers = ["alunduil"] }
  }
}
