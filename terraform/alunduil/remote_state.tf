# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Pulls project_id (and any future shared identifiers) from the bootstrap
# state so this config never re-states the same string. Both configs share
# the alunduil-tfstate bucket and the deployer SAs have read access, so the
# remote_state lookup works in CI without extra wiring.
data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = "alunduil-tfstate"
    prefix = "bootstrap"
  }
}
