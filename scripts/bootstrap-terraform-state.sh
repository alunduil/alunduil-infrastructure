#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail
set -x

PROJECT_ID="${PROJECT_ID:-alunduil}"
LOCATION="${LOCATION:-EU}"

# terraform/alunduil/ and terraform/bootstrap/ keep their state in separate
# buckets: the CI deployer SAs hold bucket-wide IAM on the alunduil/ bucket, so
# a shared bucket would let the plan workflow read bootstrap state (which holds
# the Cloudflare deployer tokens in plaintext).
BUCKETS=(alunduil-tfstate alunduil-bootstrap-tfstate)

for bucket in "${BUCKETS[@]}"; do
  if gcloud storage buckets describe "gs://${bucket}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Bucket gs://${bucket} already exists in project ${PROJECT_ID}."
  else
    gcloud storage buckets create "gs://${bucket}" \
      --project "${PROJECT_ID}" \
      --location "${LOCATION}" \
      --public-access-prevention \
      --uniform-bucket-level-access
  fi

  # Ensure versioning is enabled for state protection
  gcloud storage buckets update "gs://${bucket}" \
    --project "${PROJECT_ID}" \
    --uniform-bucket-level-access \
    --versioning
done
