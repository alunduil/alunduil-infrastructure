#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the plan parsing in test-dora-alert.sh. The timelines
# themselves run under promtool in the plan workflow.

setup() {
  # shellcheck source=test-dora-alert.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/test-dora-alert.sh"
}

# A plan holding the alert, with one absence term per argument.
plan() {
  local expr
  expr="$(printf '%s\n' "$@" | jq -Rsr 'split("\n")[:-1] | join(" or ")')"
  jq -n --arg expr "${expr}" '{planned_values: {root_module: {resources: [
    {address: "grafana_rule_group.other", values: {}},
    {address: "grafana_rule_group.dora_recording", values: {
      interval_seconds: 300,
      rule: [{
        name: "DORA rules stopped recording",
        for: "7200s",
        labels: {severity: "warning"},
        data: [
          {ref_id: "A", model: ({expr: $expr} | tojson)},
          {ref_id: "C", model: "{}"}
        ]
      }]
    }}
  ]}}}'
}

term() {
  printf 'absent_over_time(dora_deploys{repository="%s"}[%s])' "$1" "$2"
}

@test "alert_rule_file renders one repository's term with the alert's timing" {
  run alert_rule_file <<<"$(plan "$(term a 3900s)" "$(term b 3900s)")"
  [[ ${status} -eq 0 ]]
  [[ $(jq -c '.groups[0].rules' <<<"${output}") == "$(jq -nc '[{
    alert: "DORA rules stopped recording",
    expr: "absent_over_time(dora_deploys{repository=\"example\"}[3900s])",
    for: "7200s",
    labels: {severity: "warning"}
  }]')" ]]
}

@test "alert_rule_file fails when repositories' terms differ" {
  run alert_rule_file <<<"$(plan "$(term a 3900s)" "$(term b 600s)")"
  [[ ${status} -ne 0 ]]
  [[ ${output} == *"repository terms differ"* ]]
}

@test "evaluation_interval prints the alert group's interval" {
  run evaluation_interval <<<"$(plan "$(term a 3900s)")"
  [[ ${status} -eq 0 ]]
  [[ ${output} == 300s ]]
}
