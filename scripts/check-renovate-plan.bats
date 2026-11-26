#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

setup() {
  script="${BATS_TEST_DIRNAME}/check-renovate-plan.sh"
  pull_request="${BATS_TEST_TMPDIR}/pull_request.json"
  enabled='🚦 **Automerge**: Enabled.'
  disabled='🚦 **Automerge**: Disabled by config. Please merge this manually once you are satisfied.'
  armed='{"enabled_by": {"login": "renovate[bot]"}}'
}

# write_pull_request <body> [auto-merge-json]
write_pull_request() {
  jq -n --arg body "$1" --argjson auto_merge "${2:-null}" \
    '{body: $body, auto_merge: $auto_merge}' >"${pull_request}"
}

# check <resource-changes>
check() {
  run "${script}" "${pull_request}" "$1"
}

@test "accepts a held update that changes resources with auto-merge off" {
  write_pull_request "${disabled}"
  check 3
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"::notice::"* ]]
}

@test "rejects a held update that changes resources with auto-merge on" {
  write_pull_request "${disabled}" "${armed}"
  check 3
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"auto-merge is on"* ]]
}

@test "rejects an automerging update that changes resources" {
  write_pull_request "${enabled}" "${armed}"
  check 3
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"3 resource changes"* ]]
}

@test "rejects an automerging update before Renovate turns auto-merge on" {
  write_pull_request "${enabled}"
  check 3
  [[ ${status} -eq 1 ]]
}

@test "rejects an automerging update whose release notes say Disabled" {
  write_pull_request "${disabled}"$'\n'"${enabled}"
  check 3
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"resource changes"* ]]
}

@test "accepts an automerging update that changes nothing" {
  write_pull_request "${enabled}" "${armed}"
  check 0
  [[ ${status} -eq 0 ]]
}

@test "rejects a body that states neither, whatever the plan" {
  write_pull_request 'This PR contains the following updates:'
  check 0
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"neither"* ]]
}

@test "rejects a pull request that reads as empty" {
  : >"${pull_request}"
  check 0
  [[ ${status} -ne 0 ]]
}

@test "rejects a held update whose change count is empty" {
  write_pull_request "${disabled}"
  check ''
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"change count"* ]]
}
