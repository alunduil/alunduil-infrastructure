# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

output "project_id" {
  value       = google_project.env.project_id
  description = "alunduil GCP project ID"
  sensitive   = false
}

output "project_number" {
  value       = google_project.env.number
  description = "alunduil GCP project number"
  sensitive   = false
}
