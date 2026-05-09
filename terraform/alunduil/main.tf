# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

terraform {
  required_version = ">= 1.5"
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
  }
}

# CLOUDFLARE_API_TOKEN env var supplies auth.
provider "cloudflare" {}

provider "github" {
  owner = "alunduil"
}

provider "google" {
  project = "alunduil"
  region  = "europe-west1"
}
