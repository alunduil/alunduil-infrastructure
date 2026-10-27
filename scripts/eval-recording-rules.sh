#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Evaluates every recording rule a Terraform plan creates or updates against
# live data, and fails if any query or expression errors. A recording rule's
# SQL only runs inside Grafana, so a plan alone can't catch a bad one.
#
# Reads the Grafana token from TF_VAR_grafana_service_account_token, as the
# plan workflow exports it.
#
# Usage: scripts/eval-recording-rules.sh <plan.json>

BOOTSTRAP_OUTPUTS="${BOOTSTRAP_OUTPUTS:-gs://alunduil-tfstate/bootstrap-outputs.json}"
CONCURRENCY="${CONCURRENCY:-4}"

# Reads `terraform show -json` output on stdin and prints one compact JSON
# object per planned recording rule: its name and its /api/v1/eval request
# body.
recording_rule_requests() {
  jq -c '
    .resource_changes[]?
    | select(.type == "grafana_rule_group")
    | select(.change.actions | index("create") or index("update"))
    | .change.after.rule[]
    | select((.record // []) | length > 0)
    | {
        name,
        body: {data: [.data[] | {
          refId: .ref_id,
          queryType: .query_type,
          datasourceUid: .datasource_uid,
          relativeTimeRange: (.relative_time_range[0] | {from, to}),
          model: (.model | fromjson)
        }]}
      }
  '
}

# Reads an /api/v1/eval response on stdin and prints each failing node's
# reference and error.
eval_errors() {
  jq -r '.results // {} | to_entries[] | select(.value.error) | "\(.key): \(.value.error)"'
}

# Evaluates one recording_rule_requests line. Prints nothing when the rule
# evaluates cleanly.
eval_rule() {
  local request="$1" name response
  name="$(jq -r .name <<<"${request}")"

  # The token travels by file descriptor, never argv: /proc/<pid>/cmdline is
  # world-readable.
  if ! response="$(jq -c .body <<<"${request}" | curl --silent --show-error --fail-with-body \
    --header @<(printf 'Authorization: Bearer %s\n' "${token}") \
    --header 'Content-Type: application/json' \
    --data @- "${grafana_url}/api/v1/eval" 2>&1)"; then
    echo "${name}: ${response}"
    return
  fi

  eval_errors <<<"${response}" | sed "s|^|${name}: |"
}

# Skip the executable body when sourced (e.g. by eval-recording-rules.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

plan="${1:?usage: $0 <plan.json>}"
token="${TF_VAR_grafana_service_account_token:?must be set}"

grafana_url="$(gcloud storage cat "${BOOTSTRAP_OUTPUTS}" | jq -r .grafana_stack_url)"

results="$(mktemp -d)"
trap 'rm -rf "${results}"' EXIT

count=0
while read -r request; do
  if (($(jobs -rp | wc -l) >= CONCURRENCY)); then
    wait -n
  fi
  eval_rule "${request}" >"${results}/${count}" &
  count=$((count + 1))
done < <(recording_rule_requests <"${plan}")
wait

failures="$(cat "${results}"/* 2>/dev/null || true)"
echo "Evaluated ${count} recording rule(s)."
if [[ -n ${failures} ]]; then
  echo "${failures}" >&2
  exit 1
fi
