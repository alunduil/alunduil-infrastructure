# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The TrueNAS box's configuration. Only `just truenas` on the workstation
# applies it: a hosted runner reaching TrueNAS would make CI an entry point to
# the home network.

terraform {
  required_version = ">= 1.11"
  required_providers {
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
