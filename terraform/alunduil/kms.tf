# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Key rings have no delete API, and Terraform destroys a CryptoKey's versions
# but not the key. The hackage key ring and its cabal-config key are left
# undeclared.

locals {
  hackage_cloudbuild_decrypter = {
    key_ring_id = "${local.bootstrap.project_id}/global/hackage"
    role        = "roles/cloudkms.cryptoKeyDecrypter"
    member      = "serviceAccount:654280143615@cloudbuild.gserviceaccount.com"
  }
}

# Declared only so that removing it deletes the binding.
resource "google_kms_key_ring_iam_member" "hackage_cloudbuild_decrypter" {
  key_ring_id = local.hackage_cloudbuild_decrypter.key_ring_id
  role        = local.hackage_cloudbuild_decrypter.role
  member      = local.hackage_cloudbuild_decrypter.member
}

import {
  to = google_kms_key_ring_iam_member.hackage_cloudbuild_decrypter
  id = join(" ", [
    local.hackage_cloudbuild_decrypter.key_ring_id,
    local.hackage_cloudbuild_decrypter.role,
    local.hackage_cloudbuild_decrypter.member,
  ])
}
