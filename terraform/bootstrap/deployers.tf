# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The two CI identities, keyed by the role argument
# scripts/export-terraform-credentials.sh takes. Anything split per role keys
# off this map, so the pairing is stated once: binding a read-only credential to
# the apply account, or the reverse, would hand plan a write credential and
# nothing else here would notice.
locals {
  deployers = {
    ro = google_service_account.github_deployer_ro.email
    rw = google_service_account.github_deployer_rw.email
  }
}
