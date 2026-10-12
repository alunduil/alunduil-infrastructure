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
      version = "~> 8.0"
    }
    grafana = {
      source = "grafana/grafana"
      # Git Sync (App Platform) provisioning resources landed in 4.28.1.
      version = ">= 4.28.1, < 5.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
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

locals {
  # A token handed in means there was no runtime to mint one from, which is the
  # break-glass path. The provider rejects audience and identity_token together,
  # so this picks which one the block sets and nulls the other.
  tailscale_mints_own_token = var.tailscale_identity_token == ""

  # Tailscale derives this from the client id when it generates the credential,
  # documented as api.tailscale.com/<client id>.
  tailscale_audience = "api.tailscale.com/${var.tailscale_client_id}"
}

# Workload identity federation: nothing long-lived is stored. On a runner the
# provider mints an OIDC token itself and trades it for one good for an hour, so
# the client id is an identifier rather than a secret. oauth_client_id is the
# argument a federated identity uses too, not a leftover from an OAuth client.
#
# tailnet is left unset: it defaults to the tailnet owning the credentials, so
# the name never has to be tracked here.
provider "tailscale" {
  oauth_client_id = var.tailscale_client_id

  audience       = local.tailscale_mints_own_token ? local.tailscale_audience : null
  identity_token = local.tailscale_mints_own_token ? null : var.tailscale_identity_token
}
