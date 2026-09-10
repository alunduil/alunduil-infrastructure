#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Sets the read-only GCP service-account key on the Grafana Cloud data sources
# that query GCP live (Cloud Monitoring, and later Cloud Logging). The key is set
# through the Grafana API rather than Terraform so it never lands in the
# bucket-readable alunduil state; the key and the Grafana API token are both read
# from Secret Manager and never written to disk. Run once after the data source
# exists (bootstrap + terraform/alunduil apply) and again on key rotation.
#
# Usage: scripts/set-grafana-gcp-credentials.sh [datasource-uid ...]

PROJECT_ID="${PROJECT_ID:-alunduil}"
GRAFANA_URL="${GRAFANA_URL:-https://alunduil.grafana.net}"
KEY_SECRET="${KEY_SECRET:-grafana-gcp-reader-key}"
TOKEN_SECRET="${TOKEN_SECRET:-grafana-provisioner-token}"

datasource_uids=("$@")
if [[ ${#datasource_uids[@]} -eq 0 ]]; then
  datasource_uids=(gcp-cloud-monitoring)
fi

key_json="$(gcloud secrets versions access latest --secret="${KEY_SECRET}" --project="${PROJECT_ID}")"
grafana_token="$(gcloud secrets versions access latest --secret="${TOKEN_SECRET}" --project="${PROJECT_ID}")"
private_key="$(jq -r '.private_key' <<<"${key_json}")"

for uid in "${datasource_uids[@]}"; do
  current="$(curl -fsS -H "Authorization: Bearer ${grafana_token}" \
    "${GRAFANA_URL}/api/datasources/uid/${uid}")"

  # Only touch secureJsonData; Terraform owns the non-secret jsonData.
  updated="$(jq --arg pk "${private_key}" '.secureJsonData = {privateKey: $pk}' <<<"${current}")"

  curl -fsS -X PUT \
    -H "Authorization: Bearer ${grafana_token}" \
    -H "Content-Type: application/json" \
    -d "${updated}" \
    "${GRAFANA_URL}/api/datasources/uid/${uid}" >/dev/null

  echo "Set GCP credential on Grafana data source '${uid}'."
done
