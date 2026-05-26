# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# State lives in the same bucket as terraform/alunduil/ under a separate prefix.
# The bucket is created out-of-band by scripts/bootstrap-terraform-state.sh.
terraform {
  backend "gcs" {
    bucket = "alunduil-tfstate"
    prefix = "bootstrap"
  }
}
