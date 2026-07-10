# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Legacy APIs enabled in the alunduil project from past experimentation —
# none are used by any resource managed in this repo.
#
# They are codified here with `disable_on_destroy = true` so that a follow-up
# commit which deletes this file will *actually* disable them in GCP (rather
# than just dropping them from Terraform state).
#
# Before deleting this file, review the list below and move any entries you
# want to keep into project.tf (with `disable_on_destroy = false`, matching
# the other kept APIs).

resource "google_project_service" "legacy" {
  for_each = toset([
    # User-facing — review before disabling
    "calendar-json.googleapis.com",         # Google Calendar
    "generativelanguage.googleapis.com",    # Gemini / AI Studio
    "smartdevicemanagement.googleapis.com", # Nest / Google Home

    # Observability — GCP often re-enables automatically
    "monitoring.googleapis.com",

    # Compute Engine and related
    "autoscaling.googleapis.com",
    "compute.googleapis.com",
    "networkconnectivity.googleapis.com",
    "oslogin.googleapis.com",
    "routes.googleapis.com",

    # Kubernetes / containers
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerscanning.googleapis.com",
    "gkebackup.googleapis.com",

    # Build / artifacts
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "sourcerepo.googleapis.com",

    # Data stores
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com",
    "datastore.googleapis.com",
    "spanner.googleapis.com",
    "sql-component.googleapis.com",

    # Messaging
    "pubsub.googleapis.com",

    # Security / KMS
    "cloudkms.googleapis.com",

    # Legacy / deprecated
    "deploymentmanager.googleapis.com",
    "replicapool.googleapis.com",
    "replicapoolupdater.googleapis.com",
    "resourceviews.googleapis.com",
  ])

  project = local.bootstrap.project_id
  service = each.key

  disable_on_destroy = true
}
