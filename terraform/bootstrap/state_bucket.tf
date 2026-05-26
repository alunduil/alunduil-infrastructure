# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Not TF-managed: bootstrap stores its state in this bucket, so managing the
# bucket here would chicken-and-egg.
data "google_storage_bucket" "state" {
  name = "alunduil-tfstate"
}
