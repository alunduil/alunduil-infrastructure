#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the plan parsing and error reporting in
# eval-recording-rules.sh. Evaluating a rule needs live Grafana, so that path
# is left to the plan workflow.

setup() {
  # shellcheck source=eval-recording-rules.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/eval-recording-rules.sh"
}

# A rule in a rule group's planned state, recording when $2 is non-empty.
rule() {
  local name="$1" record="$2"
  cat <<JSON
{
  "name": "${name}",
  "record": ${record:-[]},
  "data": [
    {
      "ref_id": "P",
      "query_type": "Pull_Requests",
      "datasource_uid": "github",
      "relative_time_range": [{"from": 2678400, "to": 0}],
      "model": "{\"refId\":\"P\",\"repository\":\"zfs-replicate\"}"
    },
    {
      "ref_id": "OUT",
      "query_type": "",
      "datasource_uid": "__expr__",
      "relative_time_range": [{"from": 2592000, "to": 0}],
      "model": "{\"refId\":\"OUT\",\"type\":\"sql\"}"
    }
  ]
}
JSON
}

# A grafana_rule_group change with the given actions and rules.
group() {
  local actions="$1"
  shift
  local rules
  rules="$(printf '%s\n' "$@" | jq -s .)"
  jq -n --argjson actions "${actions}" --argjson rules "${rules}" \
    '{type: "grafana_rule_group", change: {actions: $actions, after: {rule: $rules}}}'
}

plan() {
  printf '%s\n' "$@" | jq -s '{resource_changes: .}'
}

RECORD='[{"from": "OUT", "metric": "delivery_deploys"}]'

@test "recording_rule_requests emits each created or updated recording rule" {
  run recording_rule_requests <<<"$(plan \
    "$(group '["create"]' "$(rule created "${RECORD}")")" \
    "$(group '["update"]' "$(rule updated "${RECORD}")")" \
    "$(group '["delete", "create"]' "$(rule replaced "${RECORD}")")")"
  [[ ${status} -eq 0 ]]
  [[ ${#lines[@]} -eq 3 ]]
  [[ $(jq -r .name <<<"${lines[0]}") == created ]]
  [[ $(jq -r .name <<<"${lines[1]}") == updated ]]
  [[ $(jq -r .name <<<"${lines[2]}") == replaced ]]
}

@test "recording_rule_requests skips alert rules and unchanged or deleted groups" {
  run recording_rule_requests <<<"$(plan \
    "$(group '["create"]' "$(rule alert "")")" \
    "$(group '["no-op"]' "$(rule unchanged "${RECORD}")")" \
    "$(group '["delete"]' "$(rule deleted "${RECORD}")")" \
    '{"type": "grafana_folder", "change": {"actions": ["create"], "after": {}}}')"
  [[ ${status} -eq 0 ]]
  [[ -z ${output} ]]
}

@test "recording_rule_requests shapes each data stage as an eval query" {
  run recording_rule_requests <<<"$(plan "$(group '["create"]' "$(rule created "${RECORD}")")")"
  [[ ${status} -eq 0 ]]
  body="$(jq -c .body <<<"${output}")"
  run jq -c '.data[0]' <<<"${body}"
  [[ ${output} == '{"refId":"P","queryType":"Pull_Requests","datasourceUid":"github","relativeTimeRange":{"from":2678400,"to":0},"model":{"refId":"P","repository":"zfs-replicate"}}' ]]
  run jq -r '.data[1].model.type' <<<"${body}"
  [[ ${output} == sql ]]
}

@test "recording_rule_requests keeps quotes, backslashes and newlines in a model intact" {
  sql='SELECT CONCAT('\''Revert "'\'', title) AS t, SUBSTRING_INDEX(message, '\''\n'\'', 1)'$'\n''FROM P'
  model="$(jq -cn --arg sql "${sql}" '{refId: "OUT", type: "sql", expression: $sql}')"
  rule_group="$(group '["create"]' "$(rule created "${RECORD}")" \
    | jq --arg model "${model}" '.change.after.rule[0].data[1].model = $model')"
  run recording_rule_requests <<<"$(plan "${rule_group}")"
  [[ ${status} -eq 0 ]]
  [[ ${#lines[@]} -eq 1 ]]
  [[ $(jq -r '.body.data[1].model.expression' <<<"${output}") == "${sql}" ]]
}

@test "eval_errors reports each failing node" {
  run eval_errors <<<'{"results": {"P": {"error": "rate limited"}, "R": {"frames": []}, "OUT": {"error": "bad sql"}}}'
  [[ ${status} -eq 0 ]]
  [[ ${#lines[@]} -eq 2 ]]
  [[ ${output} == *"P: rate limited"* ]]
  [[ ${output} == *"OUT: bad sql"* ]]
}

@test "eval_errors prints nothing for a clean evaluation" {
  run eval_errors <<<'{"results": {"P": {"frames": []}, "OUT": {"frames": []}}}'
  [[ ${status} -eq 0 ]]
  [[ -z ${output} ]]
}
