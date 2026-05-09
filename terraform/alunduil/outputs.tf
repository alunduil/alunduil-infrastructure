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

# DS fields for manual publication at the Squarespace registrar (not TF-managed).
output "alunduil_com_ds" {
  value = {
    key_tag     = cloudflare_zone_dnssec.alunduil_com.key_tag
    algorithm   = cloudflare_zone_dnssec.alunduil_com.algorithm
    digest_type = cloudflare_zone_dnssec.alunduil_com.digest_type
    digest      = cloudflare_zone_dnssec.alunduil_com.digest
    ds          = cloudflare_zone_dnssec.alunduil_com.ds
  }
  description = "DS record fields to publish at the Squarespace registrar for alunduil.com"
}
