# shellcheck shell=bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Sets a private key on a Grafana data source Terraform declares. Terraform
# can't set it: a data source keeps its credential in state, and the alunduil
# state is bucket-readable. Sourced, not run.

# gcx authenticates as the logged-in operator, so no Grafana token is read here.
# Its agent-mode hint goes to stderr, leaving stdout a single JSON document
# whichever way it is invoked.
grafana_datasource_api() {
  local method="$1" uid="$2"
  shift 2

  gcx api "/api/datasources/uid/${uid}" -X "${method}" "$@"
}

set_datasource_private_key() {
  local uid="$1" private_key="$2"

  # The key travels by stdin and environment, never argv: /proc/<pid>/cmdline is
  # world-readable, /proc/<pid>/environ is not. Only secureJsonData is touched;
  # Terraform owns the non-secret jsonData.
  grafana_datasource_api GET "${uid}" \
    | pk="${private_key}" jq '.secureJsonData = {privateKey: env.pk}' \
    | grafana_datasource_api PUT "${uid}" -d @- >/dev/null

  echo "Set private key on Grafana data source '${uid}'."
}
