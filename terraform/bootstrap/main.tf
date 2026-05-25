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
  }
}

provider "google" {
  project = "alunduil"
  region  = "europe-west1"
}

# Operator sources CLOUDFLARE_API_TOKEN before `terraform apply` from a master
# token scoped to `API Tokens Read` + `API Tokens Write` (+ access to the
# alunduil.com zone, transitively, for the deployer tokens this config mints).
# The master token never enters CI; only the minted deployer tokens do.
provider "cloudflare" {}
