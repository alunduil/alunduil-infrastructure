# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# A-01's API key, read by `just truenas`. An empty shell:
# scripts/configure-truenas-secrets.sh adds the version, so the key never
# reaches this layer's state. No deployer is granted access, because no
# workflow reaches A-01.
resource "google_secret_manager_secret" "truenas_api_key" {
  project   = google_project.env.project_id
  secret_id = "truenas-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}
