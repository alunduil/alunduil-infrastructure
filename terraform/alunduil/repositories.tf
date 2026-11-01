# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

locals {
  # An input an entry leaves unset takes the module's default.
  #
  # deploy matches the repository's row in the Repositories table of
  # docs/reference/delivery-metrics.md. A repository without one records no
  # DORA metrics. A run without an event matches any event.
  repositories = {
    "alunduil-chezmoi" = {
      description = "Personal chezmoi-managed dotfiles and host config: bootstrap a fresh host from bare OS to a working setup in one command."
      topics      = ["chezmoi", "dotfiles", "debian", "crostini", "claude-code"]
      required_status_checks = {
        contexts = [
          "Test shell scripts",
          "Validate chezmoi source",
          "Validate zellij config",
          "Validate telemetry config",
          "Check prose",
          "Run pinned tools",
        ]
        renovate_automerge = true
      }
      deploy = { class = "merge" }
    }

    "alunduil-infrastructure" = {
      required_status_checks = {
        ci_results_check = true
        # A failed detect job skips the plan, and a skipped job passes.
        contexts = ["Detect Terraform changes", "Plan Terraform changes"]
        # renovate.json holds back every update that would trigger an apply.
        renovate_automerge = true
      }
      # The Hourly Inbox sync reads GH_PROJECT_SYNC_TOKEN from this
      # environment. Pinning it to main keeps a workflow_dispatch on another
      # branch from reaching the token. Terraform doesn't set the token.
      environments = {
        "project-sync" = { deployment_branches = ["main"] }
      }
      allowed_action_patterns = ["devcontainers/ci@*"]
      deploy                  = { class = "run", workflow = "terraform-apply.yml", branch = "main" }
    }

    "blog.alunduil.com" = {
      description  = "Personal blog at blog.alunduil.com"
      homepage_url = "https://blog.alunduil.com"
      topics       = ["blog", "github-pages"]
      required_status_checks = {
        contexts = [
          "Test skill scripts",
          "Test TypeScript utilities",
          "Build the site",
          "Review dependencies",
        ]
        renovate_automerge = true
      }
      # .github/CODEOWNERS assigns every path to @alunduil.
      require_code_owner_review = true
      # Deviates from the baseline (squash only). The AstroPaper theme syncs
      # by merging upstream, and each sync diffs against the upstream parent
      # that only a merge commit keeps.
      merge_method = "merge"
      pages = {
        cname          = "blog.alunduil.com"
        build_type     = "workflow"
        https_enforced = true
      }
      allowed_action_patterns = ["withastro/action@*"]
      deploy                  = { class = "run", workflow = "cd.yml", branch = "main", event = "push" }
    }

    "collection-json.hs" = {
      description = "Collection+JSON Tools for Haskell"
      topics      = ["haskell-library", "collection-json", "haskell", "hypermedia"]
      required_status_checks = {
        ci_results_check = true
        contexts         = ["Check links"]
      }
      # Deployment environment for Hackage releases.
      environments = { hackage = {} }
      deploy       = { class = "run", workflow = "release.yml", event = "workflow_dispatch" }
    }

    "git-worktree-poi" = {
      description = "Prune git worktrees whose branch has merged or whose upstream is gone, and report what's left in a gh-poi-style summary. Reach for it when a worktree-per-branch workflow leaves stale checkouts behind; run it by hand or on a systemd timer."
      topics      = ["cli", "rust", "git", "git-worktree", "claude-code"]
      required_status_checks = {
        contexts = [
          "Run the test suite",
          "Check dependency policy",
          "Build the x86_64 Linux release",
        ]
      }
    }

    "network-arbitrary" = {
      description = "Arbitrary Instances for Network Types"
      topics      = ["haskell-library", "haskell", "network", "quickcheck"]
      required_status_checks = {
        ci_results_check   = true
        contexts           = ["Prune stale pull requests", "Check GHC matrix drift"]
        renovate_automerge = true
      }
      environments = { hackage = {} }
      # create-pull-request is nested in haskell-bounds-bump-action.
      allowed_action_patterns = [
        "nomeata/haskell-bounds-bump-action@*",
        "peter-evans/create-pull-request@*",
      ]
      deploy = { class = "run", workflow = "release.yml", event = "release" }
    }

    "projects-v2-sync" = {
      description = "Mirror issues and PRs onto a GitHub Projects v2 board from a declarative in/out spec"
      topics      = ["github-actions", "github-projects", "projects-v2", "typescript"]
      required_status_checks = {
        contexts = [
          "Run unit tests",
          "Validate PR title",
          "Review dependencies",
          "Bundle is current",
          "Action loads and exits clean",
        ]
        renovate_automerge = true
      }
      # .github/CODEOWNERS assigns every path to @alunduil.
      require_code_owner_review = true
    }

    "renovate-config" = {
      description = "Shared Renovate preset for any repo's renovate.json, and a reusable workflow that pushes hook fixes to Renovate branches."
      topics      = ["renovate", "renovate-config", "dependency-management"]
      deploy      = { class = "merge" }
    }

    "siren-json.hs" = {
      description = "Siren+JSON Tools for Haskell"
      topics      = ["haskell-library", "haskell", "siren-json", "hypermedia"]
      required_status_checks = {
        ci_results_check = true
      }
      environments = { hackage = {} }
      deploy       = { class = "release" }
    }

    "woodland-generators" = {
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
      # Codecov's upload legs and commit statuses aren't required.
      required_status_checks = {
        ci_results_check = true
        contexts = [
          "Build every package",
          "Enforce Conventional Commits",
          "Audit production dependencies",
          "Scan for live secrets",
        ]
        renovate_automerge = true
      }
      # .github/CODEOWNERS assigns every path to @alunduil.
      require_code_owner_review = true
      # Deviates from the baseline (discussions off). The repo sets
      # blank_issues_enabled: false and routes every non-bug, non-feature path
      # to a Discussions category from .github/ISSUE_TEMPLATE/config.yml, so
      # disabling this leaves help-seekers with nowhere to land.
      has_discussions = true
      template = {
        owner      = "League-of-Foundry-Developers"
        repository = "FoundryVTT-Module-Template"
      }
      deploy = { class = "release" }
    }

    "zellij-claude-pair" = {
      description = "Zellij plugin for the Claude Code pairing workflow: in-session repo picker and branch/PR status widgets plus worktree session orchestration."
      topics      = ["zellij", "zellij-plugin", "claude-code", "rust", "wasm"]
      required_status_checks = {
        ci_results_check   = true
        contexts           = ["Enforce Conventional Commits"]
        renovate_automerge = true
      }
    }

    "zfs-replicate" = {
      description    = "Replicate ZFS snapshots to a remote host over SSH (Python CLI; replication only — it doesn't create snapshots)."
      homepage_url   = "https://pypi.org/project/zfs-replicate/"
      topics         = ["zfs", "replication", "snapshots"]
      default_branch = "master"
      required_status_checks = {
        ci_results_check   = true
        contexts           = ["Validate PR title"]
        renovate_automerge = true
      }
      # .github/CODEOWNERS assigns every path to @alunduil, so this gates every
      # non-owner pull request but Renovate's.
      require_code_owner_review = true
      # Deviates from the baseline (admin-only on): write collaborators merge
      # pull requests here too.
      admin_only_updates = false
      # PyPI pins the Trusted Publisher it accepts to repo + workflow +
      # environment, so the publish job has to run in this one. No deployment
      # branch policy: the release workflow runs from a tag ref, which the
      # module's branch patterns would refuse.
      environments = { pypi = {} }
      deploy       = { class = "run", workflow = "release.yml", event = "release" }
    }
  }
}

module "repository" {
  source   = "../modules/github_repository"
  for_each = local.repositories

  name                      = each.key
  description               = lookup(each.value, "description", null)
  homepage_url              = lookup(each.value, "homepage_url", null)
  topics                    = lookup(each.value, "topics", null)
  default_branch            = lookup(each.value, "default_branch", null)
  required_status_checks    = lookup(each.value, "required_status_checks", null)
  require_code_owner_review = lookup(each.value, "require_code_owner_review", null)
  admin_only_updates        = lookup(each.value, "admin_only_updates", null)
  merge_method              = lookup(each.value, "merge_method", null)
  has_discussions           = lookup(each.value, "has_discussions", null)
  template                  = lookup(each.value, "template", null)
  environments              = lookup(each.value, "environments", null)
  pages                     = lookup(each.value, "pages", null)
  allowed_action_patterns   = lookup(each.value, "allowed_action_patterns", null)
}

import {
  to = module.repository["renovate-config"].github_repository.this
  id = "renovate-config"
}

moved {
  from = module.alunduil_chezmoi
  to   = module.repository["alunduil-chezmoi"]
}

moved {
  from = module.alunduil_infrastructure
  to   = module.repository["alunduil-infrastructure"]
}

moved {
  from = module.blog_alunduil_com
  to   = module.repository["blog.alunduil.com"]
}

moved {
  from = module.collection_json_hs
  to   = module.repository["collection-json.hs"]
}

moved {
  from = module.git_worktree_poi
  to   = module.repository["git-worktree-poi"]
}

moved {
  from = module.network_arbitrary
  to   = module.repository["network-arbitrary"]
}

moved {
  from = module.projects_v2_sync
  to   = module.repository["projects-v2-sync"]
}

moved {
  from = module.renovate_config
  to   = module.repository["renovate-config"]
}

moved {
  from = module.siren_json_hs
  to   = module.repository["siren-json.hs"]
}

moved {
  from = module.woodland_generators
  to   = module.repository["woodland-generators"]
}

moved {
  from = module.zellij_claude_pair
  to   = module.repository["zellij-claude-pair"]
}

moved {
  from = module.zfs_replicate
  to   = module.repository["zfs-replicate"]
}
