# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

terraform {
  required_version = ">= 1.7"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.19"
    }
    grafana = {
      source = "grafana/grafana"
      # Git Sync (App Platform) provisioning resources landed in 4.28.1.
      version = ">= 4.28.1, < 5.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "github" {
  owner = "alunduil"
}

provider "google" {
  project = "alunduil"
  region  = "europe-west1"
}

# Git Sync provisioning talks to the stack's App Platform API directly, so this
# is configured with url/auth/stack_id rather than the Grafana Cloud arguments
# (which fail with "Grafana App Platform API client not configured"). The stack
# coordinates come from the bootstrap layer; the token is a Secret-Manager-backed
# var exported by the workflows, mirroring cloudflare_api_token.
provider "grafana" {
  url      = local.bootstrap.grafana_stack_url
  auth     = var.grafana_service_account_token
  stack_id = local.bootstrap.grafana_stack_id
}
