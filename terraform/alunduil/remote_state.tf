# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = "alunduil-tfstate"
    prefix = "bootstrap"
  }
}
