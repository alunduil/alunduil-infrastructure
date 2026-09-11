#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Sets the read-only GCP service-account key on the Grafana Cloud data sources
# that query GCP live. Terraform can't set it: a data source keeps its credential
# in state, and the alunduil state is bucket-readable. Neither the key nor the
# API token touches disk.
#
# Usage: scripts/set-grafana-gcp-credentials.sh [datasource-uid ...]

PROJECT_ID="${PROJECT_ID:-alunduil}"
GRAFANA_URL="${GRAFANA_URL:-https://alunduil.grafana.net}"
KEY_SECRET="${KEY_SECRET:-grafana-gcp-reader-key}"
TOKEN_SECRET="${TOKEN_SECRET:-grafana-provisioner-token}"

read_secret() {
  gcloud secrets versions access latest --secret="$1" --project="${PROJECT_ID}"
}

grafana_api() {
  local method="$1" uid="$2"
  shift 2

  curl -fsS -X "${method}" \
    -H "Authorization: Bearer ${grafana_token}" \
    -H "Content-Type: application/json" \
    "$@" \
    "${GRAFANA_URL}/api/datasources/uid/${uid}"
}

set_datasource_credential() {
  local uid="$1" updated

  # Only touch secureJsonData; Terraform owns the non-secret jsonData.
  updated="$(grafana_api GET "${uid}" \
    | jq --arg pk "${private_key}" '.secureJsonData = {privateKey: $pk}')"

  grafana_api PUT "${uid}" -d "${updated}" >/dev/null

  echo "Set GCP credential on Grafana data source '${uid}'."
}

datasource_uids=("$@")
if [[ ${#datasource_uids[@]} -eq 0 ]]; then
  datasource_uids=(gcp-cloud-monitoring)
fi

grafana_token="$(read_secret "${TOKEN_SECRET}")"
private_key="$(read_secret "${KEY_SECRET}" | jq -r '.private_key')"

for uid in "${datasource_uids[@]}"; do
  set_datasource_credential "${uid}"
done
