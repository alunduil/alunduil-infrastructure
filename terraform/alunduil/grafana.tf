# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Grafana Cloud syncs dashboards from the grafana/ subdirectory of this repo via
# Git Sync, so the dashboard JSON lives here beside the rest of the
# infrastructure rather than in a standalone repo.

# GitHub App connection Git Sync authenticates through. A dedicated App installed
# only on alunduil-infrastructure keeps the grant tighter than the broad deployer
# App and lets Grafana refresh its own short-lived installation tokens, so no
# long-lived PAT is stored. The App id/installation come from the bootstrap
# remote state; the private key is a Secret-Manager-backed var (base64-encoded
# to match the provider's expected encoding).
resource "grafana_apps_provisioning_connection_v0alpha1" "git_sync" {
  metadata {
    uid = "alunduil-infrastructure-git-sync"
  }

  spec {
    title       = "alunduil-infrastructure Git Sync"
    description = "Dedicated GitHub App used by the dashboards Git Sync repository."
    type        = "github"
    url         = "https://github.com"

    github {
      app_id          = local.bootstrap.grafana_git_sync_app_id
      installation_id = local.bootstrap.grafana_git_sync_app_installation_id
    }
  }

  secure {
    private_key = {
      create = base64encode(var.grafana_git_sync_app_private_key)
    }
  }
  secure_version = 1
}

resource "grafana_apps_provisioning_repository_v0alpha1" "dashboards" {
  depends_on = [grafana_apps_provisioning_connection_v0alpha1.git_sync]

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

    connection {
      name = grafana_apps_provisioning_connection_v0alpha1.git_sync.metadata.uid
    }
  }
}
