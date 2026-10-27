#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Sets the read-only GCP service-account key on the Grafana Cloud data sources
# that query GCP live. The key never touches disk.
#
# Without arguments, targets every data source whose clientEmail is the key's
# service account.
#
# Usage: scripts/set-grafana-gcp-credentials.sh [datasource-uid ...]

PROJECT_ID="${PROJECT_ID:-alunduil}"
KEY_SECRET="${KEY_SECRET:-grafana-gcp-reader-key}"

# shellcheck source=scripts/lib/grafana-datasource.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/grafana-datasource.sh"

read_secret() {
  gcloud secrets versions access latest --secret="$1" --project="${PROJECT_ID}"
}

# Reads a /api/datasources listing on stdin and prints the UIDs of the data
# sources that authenticate as the given service account.
uids_for_client_email() {
  email="$1" jq -r '.[] | select(.jsonData.clientEmail == env.email) | .uid'
}

# Skip the executable body when sourced (e.g. by
# set-grafana-gcp-credentials.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

key="$(read_secret "${KEY_SECRET}")"
private_key="$(k="${key}" jq -rn 'env.k | fromjson | .private_key')"
client_email="$(k="${key}" jq -rn 'env.k | fromjson | .client_email')"

datasource_uids=("$@")
if [[ ${#datasource_uids[@]} -eq 0 ]]; then
  datasources="$(gcx api /api/datasources)"
  mapfile -t datasource_uids < <(uids_for_client_email "${client_email}" <<<"${datasources}")
fi

if [[ ${#datasource_uids[@]} -eq 0 ]]; then
  echo "No Grafana data source uses ${client_email}." >&2
  exit 1
fi

for uid in "${datasource_uids[@]}"; do
  set_datasource_private_key "${uid}" "${private_key}"
done
