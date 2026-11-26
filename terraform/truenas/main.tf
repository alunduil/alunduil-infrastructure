# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The TrueNAS box's configuration. Only `just truenas` on the workstation
# applies it: a hosted runner reaching TrueNAS would make CI an entry point to
# the home network.

terraform {
  # Actions landed in 1.14.
  required_version = ">= 1.14"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
    truenas = {
      source  = "truenas/truenas"
      version = "~> 1.9"
    }
  }
}

locals {
  truenas_host = "192.168.68.63"
}

# The API key arrives as TRUENAS_API_KEY.
#
# The web UI's certificate names truenas.alunduil.com, which nothing resolves, so
# verification against the LAN address fails.
provider "truenas" {
  endpoint = "wss://${local.truenas_host}/api/current"
  insecure = true
}

provider "google" {
  project = "alunduil"
}

# Read as an object rather than through terraform_remote_state, because the full
# bootstrap state holds plaintext tokens.
data "google_storage_bucket_object_content" "bootstrap" {
  bucket = "alunduil-tfstate"
  name   = "bootstrap-outputs.json"
}

locals {
  bootstrap = jsondecode(data.google_storage_bucket_object_content.bootstrap.content)
}
