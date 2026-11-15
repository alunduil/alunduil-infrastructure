# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

terraform {
  backend "gcs" {
    bucket = "alunduil-tfstate"
    prefix = "truenas"
  }
}
