# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# A-01's configuration. No workflow plans or applies this root: reaching A-01
# from a hosted runner would make CI an entry point to the home network, so
# only `just truenas` on the workstation runs it.

terraform {
  required_version = ">= 1.11"
  required_providers {
    truenas = {
      source  = "truenas/truenas"
      version = "~> 1.9"
    }
  }
}

# The API key arrives as TRUENAS_API_KEY.
#
# A-01's certificate names truenas.alunduil.com, which nothing resolves, so
# verification against the LAN address fails. #1109 moves the endpoint to the
# tailnet name, whose certificate matches, and drops insecure.
provider "truenas" {
  endpoint = "wss://192.168.68.63/api/current"
  insecure = true
}

# Proves a plan reaches the API and the key authenticates.
data "truenas_system_general" "this" {}
