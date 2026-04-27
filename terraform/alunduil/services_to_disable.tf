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
    "logging.googleapis.com",
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

  project = google_project.env.project_id
  service = each.key

  disable_on_destroy = true

  depends_on = [google_project_service.serviceusage]
}

# Import blocks so the next plan adopts the existing GCP state rather than
# trying to re-enable each API.

import {
  to = google_project_service.legacy["artifactregistry.googleapis.com"]
  id = "alunduil/artifactregistry.googleapis.com"
}

import {
  to = google_project_service.legacy["autoscaling.googleapis.com"]
  id = "alunduil/autoscaling.googleapis.com"
}

import {
  to = google_project_service.legacy["bigquery.googleapis.com"]
  id = "alunduil/bigquery.googleapis.com"
}

import {
  to = google_project_service.legacy["bigquerystorage.googleapis.com"]
  id = "alunduil/bigquerystorage.googleapis.com"
}

import {
  to = google_project_service.legacy["calendar-json.googleapis.com"]
  id = "alunduil/calendar-json.googleapis.com"
}

import {
  to = google_project_service.legacy["cloudbuild.googleapis.com"]
  id = "alunduil/cloudbuild.googleapis.com"
}

import {
  to = google_project_service.legacy["cloudkms.googleapis.com"]
  id = "alunduil/cloudkms.googleapis.com"
}

import {
  to = google_project_service.legacy["compute.googleapis.com"]
  id = "alunduil/compute.googleapis.com"
}

import {
  to = google_project_service.legacy["container.googleapis.com"]
  id = "alunduil/container.googleapis.com"
}

import {
  to = google_project_service.legacy["containeranalysis.googleapis.com"]
  id = "alunduil/containeranalysis.googleapis.com"
}

import {
  to = google_project_service.legacy["containerscanning.googleapis.com"]
  id = "alunduil/containerscanning.googleapis.com"
}

import {
  to = google_project_service.legacy["datastore.googleapis.com"]
  id = "alunduil/datastore.googleapis.com"
}

import {
  to = google_project_service.legacy["deploymentmanager.googleapis.com"]
  id = "alunduil/deploymentmanager.googleapis.com"
}

import {
  to = google_project_service.legacy["generativelanguage.googleapis.com"]
  id = "alunduil/generativelanguage.googleapis.com"
}

import {
  to = google_project_service.legacy["gkebackup.googleapis.com"]
  id = "alunduil/gkebackup.googleapis.com"
}

import {
  to = google_project_service.legacy["logging.googleapis.com"]
  id = "alunduil/logging.googleapis.com"
}

import {
  to = google_project_service.legacy["monitoring.googleapis.com"]
  id = "alunduil/monitoring.googleapis.com"
}

import {
  to = google_project_service.legacy["networkconnectivity.googleapis.com"]
  id = "alunduil/networkconnectivity.googleapis.com"
}

import {
  to = google_project_service.legacy["oslogin.googleapis.com"]
  id = "alunduil/oslogin.googleapis.com"
}

import {
  to = google_project_service.legacy["pubsub.googleapis.com"]
  id = "alunduil/pubsub.googleapis.com"
}

import {
  to = google_project_service.legacy["replicapool.googleapis.com"]
  id = "alunduil/replicapool.googleapis.com"
}

import {
  to = google_project_service.legacy["replicapoolupdater.googleapis.com"]
  id = "alunduil/replicapoolupdater.googleapis.com"
}

import {
  to = google_project_service.legacy["resourceviews.googleapis.com"]
  id = "alunduil/resourceviews.googleapis.com"
}

import {
  to = google_project_service.legacy["routes.googleapis.com"]
  id = "alunduil/routes.googleapis.com"
}

import {
  to = google_project_service.legacy["smartdevicemanagement.googleapis.com"]
  id = "alunduil/smartdevicemanagement.googleapis.com"
}

import {
  to = google_project_service.legacy["sourcerepo.googleapis.com"]
  id = "alunduil/sourcerepo.googleapis.com"
}

import {
  to = google_project_service.legacy["spanner.googleapis.com"]
  id = "alunduil/spanner.googleapis.com"
}

import {
  to = google_project_service.legacy["sql-component.googleapis.com"]
  id = "alunduil/sql-component.googleapis.com"
}
