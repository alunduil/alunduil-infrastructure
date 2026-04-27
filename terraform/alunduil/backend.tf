# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# State is stored in GCS bucket created by scripts/bootstrap-terraform-state.sh
terraform {
  backend "gcs" {
    bucket = "alunduil-tfstate"
    prefix = "alunduil"
  }
}
