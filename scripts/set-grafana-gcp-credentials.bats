#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the target selection in set-grafana-gcp-credentials.sh. The
# gcloud and gcx paths that read and set the key are not exercised.

setup() {
  # shellcheck source=set-grafana-gcp-credentials.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/set-grafana-gcp-credentials.sh"
}

READER="grafana-gcp-reader@example.iam.gserviceaccount.com"

datasources() {
  cat <<JSON
[
  {"uid": "gcp-cloud-monitoring", "jsonData": {"clientEmail": "${READER}"}},
  {"uid": "gcp-cloud-logging", "jsonData": {"clientEmail": "${READER}"}},
  {"uid": "other-gcp", "jsonData": {"clientEmail": "someone-else@example.iam.gserviceaccount.com"}},
  {"uid": "grafanacloud-prom", "jsonData": {}}
]
JSON
}

@test "uids_for_client_email selects every data source using the key's account" {
  run uids_for_client_email "${READER}" <<<"$(datasources)"
  [[ ${status} -eq 0 ]]
  [[ ${#lines[@]} -eq 2 ]]
  [[ ${lines[0]} == gcp-cloud-monitoring ]]
  [[ ${lines[1]} == gcp-cloud-logging ]]
}

@test "uids_for_client_email prints nothing when no data source matches" {
  run uids_for_client_email "nobody@example.iam.gserviceaccount.com" <<<"$(datasources)"
  [[ ${status} -eq 0 ]]
  [[ -z ${output} ]]
}
