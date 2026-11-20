#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Tests the "DORA rules stopped recording" alert from a Terraform plan
# against the timelines in terraform/alunduil/dora-alert-tests.yml.
#
# Usage: scripts/test-dora-alert.sh <plan.json>

ALERT_GROUP='.planned_values.root_module.resources[] | select(.address == "grafana_rule_group.dora_recording") | .values'

# Reads `terraform show -json` output on stdin and prints the alert as a
# Prometheus rule file. Every repository's term must match, so a repository
# named example stands in for all of them. The rule file drops Grafana's
# threshold stage: it fires above 0, and absent_over_time returns 1.
alert_rule_file() {
  jq -e "${ALERT_GROUP}"'
    | .rule[0] as $rule
    | [$rule.data[] | select(.ref_id == "A") | .model | fromjson | .expr
      | splits(" or ") | gsub("repository=\"[^\"]*\""; "repository=\"example\"")]
    | unique
    | if length != 1 then error("repository terms differ: \(.)") else . end
    | {groups: [{name: "dora", rules: [{
        alert: $rule.name, expr: .[0], for: $rule.for, labels: $rule.labels
      }]}]}
  '
}

# Reads `terraform show -json` output on stdin and prints the alert group's
# evaluation interval as a duration.
evaluation_interval() {
  jq -er "${ALERT_GROUP}"' | "\(.interval_seconds)s"'
}

# Skip the executable body when sourced (e.g. by test-dora-alert.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

plan="${1:?usage: $0 <plan.json>}"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

alert_rule_file <"${plan}" >"${work}/rules.json"
{
  cat "$(dirname "$0")/../terraform/alunduil/dora-alert-tests.yml"
  echo "rule_files: [rules.json]"
  echo "evaluation_interval: $(evaluation_interval <"${plan}")"
} >"${work}/tests.yml"

promtool test rules "${work}/tests.yml"
