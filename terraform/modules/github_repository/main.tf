# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

resource "github_repository" "this" {
  name         = var.name
  description  = var.description
  homepage_url = var.homepage_url
  topics       = var.topics

  visibility                  = "public"
  has_issues                  = true
  has_projects                = false
  has_wiki                    = false
  has_discussions             = var.has_discussions
  allow_merge_commit          = false
  allow_squash_merge          = true
  allow_rebase_merge          = false
  allow_auto_merge            = var.renovate_automerge
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"
  merge_commit_title          = "MERGE_MESSAGE"
  merge_commit_message        = "PR_TITLE"
  delete_branch_on_merge      = true
  archive_on_destroy          = true

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }

  dynamic "template" {
    for_each = var.template != null ? [var.template] : []
    content {
      owner                = template.value.owner
      repository           = template.value.repository
      include_all_branches = template.value.include_all_branches
    }
  }
}

resource "github_branch_default" "this" {
  repository = github_repository.this.name
  branch     = var.default_branch
}

locals {
  # Mode "always" keeps direct pushes to the default branch possible.
  admin_bypass_actor = {
    actor_id    = 5 # built-in repository "admin" role
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  renovate_app_id = 2740 # GET /apps/renovate

  # Mode "pull_request" lets Renovate merge its pull requests without letting
  # it push to the default branch.
  renovate_merge_bypass = var.renovate_automerge ? [{
    actor_id    = local.renovate_app_id
    actor_type  = "Integration"
    bypass_mode = "pull_request"
  }] : []
}

# Rulesets rather than classic github_branch_protection: rulesets are GitHub's
# strategic mechanism and the only one with first-class bypass actors. Bypass
# actors are per ruleset, so each ruleset holds one policy and an actor
# bypassing it skips that policy alone.
resource "github_repository_ruleset" "default_branch" {
  name        = "default"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  depends_on = [github_branch_default.this]

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  bypass_actors {
    actor_id    = local.admin_bypass_actor.actor_id
    actor_type  = local.admin_bypass_actor.actor_type
    bypass_mode = local.admin_bypass_actor.bypass_mode
  }

  # No required_signatures: GitHub already signs squash merges, so it would be
  # redundant on the default branch while adding friction to direct pushes.
  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true
  }
}

# Merging a pull request updates the branch too, so only bypass actors can
# merge.
resource "github_repository_ruleset" "admin_only" {
  count = var.admin_only_updates ? 1 : 0

  name        = "admin-only"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  depends_on = [github_branch_default.this]

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = concat([local.admin_bypass_actor], local.renovate_merge_bypass)
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    update = true
  }
}

# The admin bypasses because a solo maintainer can't satisfy a required review.
resource "github_repository_ruleset" "review" {
  name        = "review"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  depends_on = [github_branch_default.this]

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = concat([local.admin_bypass_actor], local.renovate_merge_bypass)
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    # Code owner review is a separate condition from the review count, so a
    # repo can gate on CODEOWNERS while the count stays at 0.
    pull_request {
      required_approving_review_count   = 0
      require_code_owner_review         = var.require_code_owner_review
      required_review_thread_resolution = true
    }
  }
}

# Renovate is absent from the bypass list, so its merges wait on these checks.
resource "github_repository_ruleset" "checks" {
  count = var.required_status_checks != null ? 1 : 0

  name        = "checks"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  depends_on = [github_branch_default.this]

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  bypass_actors {
    actor_id    = local.admin_bypass_actor.actor_id
    actor_type  = local.admin_bypass_actor.actor_type
    bypass_mode = local.admin_bypass_actor.bypass_mode
  }

  rules {
    required_status_checks {
      strict_required_status_checks_policy = var.required_status_checks.strict

      dynamic "required_check" {
        for_each = var.required_status_checks.contexts
        content {
          context = required_check.value
        }
      }
    }
  }
}

# Without this, anyone who can push to a Renovate branch could add commits to a
# pull request Renovate then merges past review.
resource "github_repository_ruleset" "renovate" {
  count = var.renovate_automerge ? 1 : 0

  name        = "renovate"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/renovate/**"]
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = [
      local.admin_bypass_actor,
      { actor_id = local.renovate_app_id, actor_type = "Integration", bypass_mode = "always" },
    ]
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    update = true
  }
}


# Load-bearing for Renovate, not just for the GitHub UI: Renovate's
# vulnerabilityAlerts handling reads this advisory feed to raise its fix PRs,
# and goes quiet if the feed is off.
resource "github_repository_vulnerability_alerts" "this" {
  repository = github_repository.this.name
}

# Off because Renovate owns dependency PRs here and already fixes the
# advisories the feed above surfaces — GitHub's own fix PRs would duplicate it.
# Declared rather than omitted so enabling it in the UI drifts back off.
resource "github_repository_dependabot_security_updates" "this" {
  repository = github_repository.this.name
  enabled    = false
}

# A workflow's own permissions: block overrides this outright, so this governs
# only the jobs that declare none.
resource "github_workflow_repository_permissions" "this" {
  repository                       = github_repository.this.name
  default_workflow_permissions     = "read"
  can_approve_pull_request_reviews = false
}

locals {
  # Actions two or more repos call, counting those nested in composite actions.
  baseline_allowed_action_patterns = [
    "8c6794b6/hpc-codecov-action@*",
    "amannn/action-semantic-pull-request@*",
    "bats-core/bats-action@*",
    "haskell-actions/hlint-setup@*",
    "haskell-actions/setup@*",
    "JasonEtco/create-an-issue@*",
    "lycheeverse/lychee-action@*",
    "peter-evans/create-issue-from-file@*",
    "pnpm/action-setup@*",
    "reviewdog/action-setup@*",
    "tox-dev/action-pre-commit-uv@*",
  ]
}

# A workflow calling an unlisted action fails at job setup, so allow-list a new
# action before merging the workflow that calls it.
resource "github_actions_repository_permissions" "this" {
  repository           = github_repository.this.name
  allowed_actions      = "selected"
  sha_pinning_required = true

  allowed_actions_config {
    github_owned_allowed = true
    verified_allowed     = true
    patterns_allowed     = concat(local.baseline_allowed_action_patterns, var.allowed_action_patterns)
  }
}

resource "github_repository_environment" "this" {
  for_each = var.environments

  repository  = github_repository.this.name
  environment = each.key

  dynamic "deployment_branch_policy" {
    for_each = length(each.value.deployment_branches) > 0 ? [1] : []
    content {
      protected_branches     = false
      custom_branch_policies = true
    }
  }
}

resource "github_repository_environment_deployment_policy" "this" {
  for_each = merge([
    for env_name, env in var.environments : {
      for pattern in env.deployment_branches :
      "${env_name}:${pattern}" => { environment = env_name, pattern = pattern }
    }
  ]...)

  repository     = github_repository.this.name
  environment    = github_repository_environment.this[each.value.environment].environment
  branch_pattern = each.value.pattern
}

resource "github_repository_pages" "this" {
  count = var.pages != null ? 1 : 0

  repository     = github_repository.this.name
  build_type     = var.pages.build_type
  cname          = var.pages.cname
  https_enforced = var.pages.https_enforced

  # source is only valid for build_type = "legacy"; the GitHub API rejects it
  # for workflow builds.
  dynamic "source" {
    for_each = var.pages.build_type == "legacy" ? [1] : []
    content {
      branch = var.default_branch
    }
  }
}
