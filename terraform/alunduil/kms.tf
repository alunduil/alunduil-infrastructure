# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The hackage key ring is left over from Hackage publishing through Cloud
# Build. Key rings have no delete API, so it stays in the project. Its
# cabal-config key has no remaining versions. Destroying a CryptoKey in
# Terraform only destroys its versions, so the key itself is deleted with
# gcloud instead.
#
# Adopted so that removing this block deletes the binding.
resource "google_kms_key_ring_iam_member" "hackage_cloudbuild_decrypter" {
  key_ring_id = "${local.bootstrap.project_id}/global/hackage"
  role        = "roles/cloudkms.cryptoKeyDecrypter"
  member      = "serviceAccount:654280143615@cloudbuild.gserviceaccount.com"
}

import {
  to = google_kms_key_ring_iam_member.hackage_cloudbuild_decrypter
  id = "${local.bootstrap.project_id}/global/hackage roles/cloudkms.cryptoKeyDecrypter serviceAccount:654280143615@cloudbuild.gserviceaccount.com"
}
