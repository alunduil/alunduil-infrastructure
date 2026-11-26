# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Non-sensitive bootstrap values, published by terraform/bootstrap/ as a JSON
# object in the shared state bucket. The full bootstrap state holds plaintext
# tokens, so this layer reads the published object rather than that state.
data "google_storage_bucket_object_content" "bootstrap" {
  bucket = "alunduil-tfstate"
  name   = "bootstrap-outputs.json"
}

locals {
  bootstrap = jsondecode(data.google_storage_bucket_object_content.bootstrap.content)
}
