# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Grafana Cloud syncs dashboards from the grafana/ subdirectory of this repo via
# Git Sync, so the dashboard JSON lives here beside the rest of the
# infrastructure rather than in a standalone repo.
resource "grafana_apps_provisioning_repository_v0alpha1" "dashboards" {
  metadata {
    uid = "alunduil-infrastructure-dashboards"
  }

  spec {
    title       = "alunduil-infrastructure dashboards"
    description = "Dashboards provisioned from the grafana/ subdirectory of alunduil-infrastructure."
    type        = "github"

    # Only the branch (pull-request) workflow: the default-branch ruleset blocks
    # direct pushes to main, so UI edits land as PRs to review, not commits.
    workflows = ["branch"]

    sync {
      enabled          = true
      target           = "folder"
      interval_seconds = 60
    }

    github {
      url    = "https://github.com/alunduil/alunduil-infrastructure"
      branch = "main"
      path   = "grafana"
    }
  }

  secure {
    token = {
      create = var.grafana_git_sync_github_token
    }
  }
  secure_version = 1
}
