#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail
set -x

BUCKET_NAME="${BUCKET_NAME:-alunduil-tfstate}"
PROJECT_ID="${PROJECT_ID:-alunduil}"
LOCATION="${LOCATION:-EU}"

# Create bucket if it doesn't exist
if gcloud storage buckets describe "gs://${BUCKET_NAME}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Bucket gs://${BUCKET_NAME} already exists in project ${PROJECT_ID}."
else
  gcloud storage buckets create "gs://${BUCKET_NAME}" \
    --project "${PROJECT_ID}" \
    --location "${LOCATION}" \
    --public-access-prevention \
    --uniform-bucket-level-access
fi

# Ensure versioning is enabled for state protection
gcloud storage buckets update "gs://${BUCKET_NAME}" \
  --project "${PROJECT_ID}" \
  --uniform-bucket-level-access \
  --versioning
