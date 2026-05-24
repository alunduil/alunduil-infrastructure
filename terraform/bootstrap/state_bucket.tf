# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The state bucket itself is not Terraform-managed: bootstrap stores its own
# state in this bucket, so managing it here would create a chicken-and-egg.
# scripts/bootstrap-terraform-state.sh creates the bucket before first apply.
# This data source pulls its identity for downstream IAM bindings on the
# deployer service accounts.
data "google_storage_bucket" "state" {
  name = "alunduil-tfstate"
}
