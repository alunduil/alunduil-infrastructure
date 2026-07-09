# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Non-sensitive bootstrap values, published by terraform/bootstrap/ as a JSON
# object in the shared state bucket. Read as an object rather than via
# terraform_remote_state because the deployer SAs have no IAM on the bootstrap
# state bucket (that isolation closes #80), and the full bootstrap state holds
# plaintext tokens.
data "google_storage_bucket_object_content" "bootstrap" {
  bucket = "alunduil-tfstate"
  name   = "bootstrap-outputs.json"
}

locals {
  bootstrap = jsondecode(data.google_storage_bucket_object_content.bootstrap.content)
}
