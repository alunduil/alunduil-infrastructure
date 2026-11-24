# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

data "github_user" "operator" {
  username = "alunduil"
}

locals {
  haskell_required_status_checks = {
    ci_results_check      = true
    codecov_project_check = true
    # Jobs from the Haskell libraries' daily.yml and weekly.yml. Those
    # workflows also run on pull requests, because a required check must
    # report on every pull request.
    contexts           = ["Prune stale pull requests", "Check GHC series drift", "Check links"]
    renovate_automerge = true
  }

  # A README-only repository has no test job to require.
  readme_only_required_status_checks = {}

  # A registry upload or an attached release asset can't be recalled, so the
  # operator approves each one (ADR 0004).
  publish_approval = { reviewers = [tonumber(data.github_user.operator.id)] }

  # An input an entry leaves unset takes the module's default.
  #
  # deploy matches the repository's row in the Repositories table of
  # docs/reference/delivery-metrics.md. A repository without one records no
  # DORA metrics. A run without an event matches any event.
  repositories = {
    "agent-plugins" = {
      description            = "Install alunduil's agent skills, hooks, and MCP servers on any host by adding this repository as a plugin marketplace."
      topics                 = ["agent-plugins", "agent-skills", "claude-code", "claude-code-plugins"]
      required_status_checks = local.readme_only_required_status_checks
      deploy                 = { class = "merge" }
    }

    "alunduil-chezmoi" = {
      description = "Personal chezmoi-managed dotfiles and host config: bootstrap a fresh host from bare OS to a working setup in one command."
      topics      = ["chezmoi", "dotfiles", "debian", "crostini", "claude-code"]
      required_status_checks = {
        contexts = [
          "Test shell scripts",
          "Validate chezmoi source",
          "Validate zellij config",
          "Validate telemetry config",
          "Verify systemd units",
          "Check prose",
          "Run pinned tools",
          "Bootstrap a fresh Debian host",
        ]
        renovate_automerge = true
      }
      deploy = { class = "merge" }
    }

    "alunduil-infrastructure" = {
      required_status_checks = {
        ci_results_check = true
        contexts = [
          # A failed detect job skips the plan, and a skipped job passes.
          "Detect Terraform changes",
          "Plan Terraform changes",
        ]
        # The admin merges past this one after reading the plan.
        admin_bypassable_contexts = ["Confirm lock file maintenance plans no changes"]
        # An update that triggers an apply automerges only when its plan
        # changes nothing. renovate.json holds back the rest.
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
          "Check workflow dry runs",
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
      description            = "Collection+JSON Tools for Haskell"
      topics                 = ["haskell-library", "collection-json", "haskell", "hypermedia"]
      required_status_checks = local.haskell_required_status_checks
      admin_only_updates     = true
      environments = {
        hackage = { deployment_tags = ["v*"], approval = local.publish_approval }
        # Holds the same token as hackage, without an approval, so the
        # candidate upload doesn't wait.
        "hackage-candidate" = { deployment_tags = ["v*"] }
      }
      deploy = { class = "run", workflow = "release.yml", event = "workflow_dispatch" }
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
        renovate_automerge = true
      }
    }

    "network-arbitrary" = {
      description            = "Arbitrary Instances for Network Types"
      topics                 = ["haskell-library", "haskell", "network", "quickcheck"]
      required_status_checks = local.haskell_required_status_checks
      admin_only_updates     = true
      environments           = { hackage = { deployment_tags = ["v*"], approval = local.publish_approval } }
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

    "release-gate" = {
      description            = "Approve a deployment only when its commit is on the repository's default branch, by answering GitHub's custom deployment protection rule from a Cloudflare Worker."
      topics                 = ["github-app", "cloudflare-workers", "deployment-protection-rules", "supply-chain-security"]
      required_status_checks = local.readme_only_required_status_checks
    }

    "renovate-config" = {
      description = "Shared Renovate preset for any repo's renovate.json, and a reusable workflow that pushes hook fixes to Renovate branches."
      topics      = ["renovate", "renovate-config", "dependency-management"]
      required_status_checks = {
        # Renovate merges here without review, and a broken
        # fix-renovate-hooks.yml breaks every repository that calls it.
        contexts           = ["Report the hook-fix self-test", "Enforce Conventional Commits"]
        renovate_automerge = true
      }
      # Every repository reads its Renovate policy from this default branch.
      admin_only_updates = true
      # The self-test App commits planted faults to the branches it opens.
      unprotected_renovate_branches = ["renovate/hook-fix-selftest-*"]
      deploy                        = { class = "merge" }
    }

    "siren-json.hs" = {
      description            = "Siren+JSON Tools for Haskell"
      topics                 = ["haskell-library", "haskell", "siren-json", "hypermedia"]
      required_status_checks = local.haskell_required_status_checks
      admin_only_updates     = true
      # The hackage environment isn't scoped to tags, so its release tags are
      # listed here.
      release_tag_patterns = ["v*"]
      environments         = { hackage = { approval = local.publish_approval } }
      deploy               = { class = "release" }
    }

    "vale-styles" = {
      description            = "Lint docs, code comments, and AI guidance against one set of house rules by adding this Vale package to any repository's .vale.ini."
      topics                 = ["vale", "vale-style", "prose-linting", "style-guide"]
      required_status_checks = local.readme_only_required_status_checks
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
      # Codecov's upload legs aren't required.
      required_status_checks = {
        ci_results_check      = true
        codecov_project_check = true
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
      # release-please names each tag <component>@<version>. No environment
      # publishes from the woodland-generators-v* tags.
      release_tag_patterns = ["woodland-generators-v*"]
      environments         = { release = { deployment_tags = ["foundry-module@*"], approval = local.publish_approval } }
      deploy               = { class = "release" }
    }

    "zellij-claude-pair" = {
      description = "Zellij plugin for the Claude Code pairing workflow: in-session repo picker and branch/PR status widgets plus worktree session orchestration."
      topics      = ["zellij", "zellij-plugin", "claude-code", "rust", "wasm"]
      required_status_checks = {
        ci_results_check   = true
        contexts           = ["Enforce Conventional Commits"]
        renovate_automerge = true
      }
      environments = { release = { deployment_tags = ["v*"], approval = local.publish_approval } }
    }

    "zfs-replicate" = {
      description  = "Replicate ZFS snapshots to a remote host over SSH (Python CLI; replication only — it doesn't create snapshots)."
      homepage_url = "https://pypi.org/project/zfs-replicate/"
      topics       = ["zfs", "replication", "snapshots"]
      required_status_checks = {
        ci_results_check      = true
        codecov_project_check = true
        contexts              = ["Validate PR title"]
        renovate_automerge    = true
      }
      # .github/CODEOWNERS assigns every path to @alunduil, so this gates every
      # non-owner pull request but Renovate's.
      require_code_owner_review = true
      # PyPI pins the Trusted Publisher it accepts to repo + workflow +
      # environment, so the publish job has to run in this one. A `release`
      # event runs from the release's tag, which no branch pattern matches.
      environments = { pypi = { deployment_tags = ["v*.*.*"], approval = local.publish_approval } }
      deploy       = { class = "run", workflow = "release.yml", event = "release" }
    }
  }
}

module "repository" {
  source   = "../modules/github_repository"
  for_each = local.repositories

  name                          = each.key
  description                   = lookup(each.value, "description", null)
  homepage_url                  = lookup(each.value, "homepage_url", null)
  topics                        = lookup(each.value, "topics", null)
  default_branch                = lookup(each.value, "default_branch", null)
  required_status_checks        = lookup(each.value, "required_status_checks", null)
  require_code_owner_review     = lookup(each.value, "require_code_owner_review", null)
  admin_only_updates            = lookup(each.value, "admin_only_updates", null)
  unprotected_renovate_branches = lookup(each.value, "unprotected_renovate_branches", null)
  merge_method                  = lookup(each.value, "merge_method", null)
  has_discussions               = lookup(each.value, "has_discussions", null)
  template                      = lookup(each.value, "template", null)
  environments                  = lookup(each.value, "environments", null)
  pages                         = lookup(each.value, "pages", null)
  allowed_action_patterns       = lookup(each.value, "allowed_action_patterns", null)
  release_tag_patterns          = lookup(each.value, "release_tag_patterns", null)
}

locals {
  # Repositories created with gh that Terraform hasn't imported yet. Drop a
  # name once the apply on main has imported it.
  adopted_repositories = toset(["agent-plugins", "release-gate", "vale-styles"])
}

import {
  for_each = local.adopted_repositories
  to       = module.repository[each.key].github_repository.this
  id       = each.key
}
