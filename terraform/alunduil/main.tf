# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

terraform {
  required_version = ">= 1.5"
  required_providers {
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

provider "github" {
  owner = "alunduil"
}

provider "google" {
  project = "alunduil"
  region  = "europe-west1"
}
