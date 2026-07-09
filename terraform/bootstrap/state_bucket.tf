# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Backs terraform/alunduil/ state. Referenced here only to attach deployer-SA
# IAM; created out-of-band by scripts/bootstrap-terraform-state.sh, so it stays
# a data source rather than a managed resource.
data "google_storage_bucket" "state" {
  name = "alunduil-tfstate"
}
