# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# terraform/bootstrap/ publishes its non-sensitive values as this object. Its
# state holds plaintext tokens, so this layer reads the object instead.
data "google_storage_bucket_object_content" "bootstrap" {
  bucket = "alunduil-tfstate"
  name   = "bootstrap-outputs.json"
}

locals {
  bootstrap = jsondecode(data.google_storage_bucket_object_content.bootstrap.content)
}
