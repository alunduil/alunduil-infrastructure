# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The Gmail app password the NanoPi-NEO3's Exim relays mail with. An empty
# shell: `just nanopi-neo3` asks for the password and adds the version, so it
# never reaches this layer's state. No deployer is granted access, because no
# workflow reaches the box.
resource "google_secret_manager_secret" "gmail_app_password_nanopi_neo3" {
  project   = google_project.env.project_id
  secret_id = "gmail-app-password-nanopi-neo3"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}
