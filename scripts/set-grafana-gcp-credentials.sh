#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Sets the read-only GCP service-account key on the Grafana Cloud data sources
# that query GCP live. Terraform can't set it: a data source keeps its credential
# in state, and the alunduil state is bucket-readable. The key never touches
# disk.
#
# Without arguments, the targets are every data source whose clientEmail names
# the key's service account, so a new GCP data source needs no edit here.
#
# Usage: scripts/set-grafana-gcp-credentials.sh [datasource-uid ...]

PROJECT_ID="${PROJECT_ID:-alunduil}"
KEY_SECRET="${KEY_SECRET:-grafana-gcp-reader-key}"

read_secret() {
  gcloud secrets versions access latest --secret="$1" --project="${PROJECT_ID}"
}

# gcx authenticates as the logged-in operator, so no Grafana token is read here.
# Its agent-mode hint goes to stderr, leaving stdout a single JSON document
# whichever way it is invoked.
grafana_api() {
  local method="$1" uid="$2"
  shift 2

  gcx api "/api/datasources/uid/${uid}" -X "${method}" "$@"
}

set_datasource_credential() {
  local uid="$1"

  # The key travels by stdin and environment, never argv: /proc/<pid>/cmdline is
  # world-readable, /proc/<pid>/environ is not. Only secureJsonData is touched;
  # Terraform owns the non-secret jsonData.
  grafana_api GET "${uid}" \
    | pk="${private_key}" jq '.secureJsonData = {privateKey: env.pk}' \
    | grafana_api PUT "${uid}" -d @- >/dev/null

  echo "Set GCP credential on Grafana data source '${uid}'."
}

key="$(read_secret "${KEY_SECRET}")"
private_key="$(k="${key}" jq -rn 'env.k | fromjson | .private_key')"
client_email="$(k="${key}" jq -rn 'env.k | fromjson | .client_email')"

datasource_uids=("$@")
if [[ ${#datasource_uids[@]} -eq 0 ]]; then
  datasources="$(gcx api /api/datasources)"
  mapfile -t datasource_uids < <(
    email="${client_email}" jq -r \
      '.[] | select(.jsonData.clientEmail == env.email) | .uid' <<<"${datasources}"
  )
fi

if [[ ${#datasource_uids[@]} -eq 0 ]]; then
  echo "No Grafana data source uses ${client_email}." >&2
  exit 1
fi

for uid in "${datasource_uids[@]}"; do
  set_datasource_credential "${uid}"
done
