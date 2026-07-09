# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

terraform {
  required_version = ">= 1.7"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.19"
    }
    grafana = {
      source  = "grafana/grafana"
      version = ">= 4.28.1, < 5.0"
    }
  }
}

provider "google" {
  project = "alunduil"
  region  = "europe-west1"
}

provider "cloudflare" {
  api_token = var.cloudflare_master_token
}

# Cloud mode (cloud_access_policy_token) to read the stack and derive a
# provisioning service-account token. The alunduil layer configures a separate
# grafana provider in App Platform mode against the same stack.
provider "grafana" {
  cloud_access_policy_token = var.grafana_cloud_access_policy_token
}
