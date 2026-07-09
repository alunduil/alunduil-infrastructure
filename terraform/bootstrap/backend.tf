# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Dedicated bucket, separate from terraform/alunduil/, so the CI deployer SAs —
# which hold bucket-wide IAM on alunduil-tfstate — can't read bootstrap state.
# The bucket is created out-of-band by scripts/bootstrap-terraform-state.sh.
terraform {
  backend "gcs" {
    bucket = "alunduil-bootstrap-tfstate"
    prefix = "bootstrap"
  }
}
