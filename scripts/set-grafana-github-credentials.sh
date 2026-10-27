#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Sets the read-only GitHub App's private key on the Grafana GitHub data source.
# Terraform can't set it: a data source keeps its credential in state, and the
# alunduil state is bucket-readable. The key never touches disk.
#
# Usage: scripts/set-grafana-github-credentials.sh

PROJECT_ID="${PROJECT_ID:-alunduil}"
KEY_SECRET="${KEY_SECRET:-grafana-github-app-private-key}"
DATASOURCE_UID="${DATASOURCE_UID:-github}"

# gcx authenticates as the logged-in operator, so no Grafana token is read here.
grafana_api() {
  local method="$1"
  shift

  gcx api "/api/datasources/uid/${DATASOURCE_UID}" -X "${method}" "$@"
}

private_key="$(gcloud secrets versions access latest --secret="${KEY_SECRET}" --project="${PROJECT_ID}")"

# The key travels by stdin and environment, never argv: /proc/<pid>/cmdline is
# world-readable, /proc/<pid>/environ is not. Only secureJsonData is touched;
# Terraform owns the non-secret jsonData.
grafana_api GET \
  | pk="${private_key}" jq '.secureJsonData = {privateKey: env.pk}' \
  | grafana_api PUT -d @- >/dev/null

echo "Set GitHub App key on Grafana data source '${DATASOURCE_UID}'."
