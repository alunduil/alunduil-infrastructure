#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

setup() {
  # shellcheck source=lib/threat-model.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/lib/threat-model.sh"

  docs="${BATS_TEST_DIRNAME}/../docs/explanation"
  # Each entry is a data flow diagram and the threat model that walks it.
  threat_models=(
    "release-path-data-flow.md threat-model-release-path.md"
    "renovate-data-flow.md threat-model-renovate.md"
  )
}

# Runs check, given a diagram and model path, for every pair, and fails
# naming each model whose check printed anything.
each_threat_model() {
  local message="$1" check="$2" pair diagram model found failed=0
  for pair in "${threat_models[@]}"; do
    read -r diagram model <<<"${pair}"
    found="$("${check}" "${docs}/${diagram}" "${docs}/${model}")" || failed=1
    if [[ -n ${found} ]]; then
      printf '%s %s:\n%s\n' "${message}" "${model}" "${found}" >&2
      failed=1
    fi
  done
  return "${failed}"
}

# incomplete_rows reads only the model.
incomplete_fields() {
  incomplete_rows "$2"
}

@test "each threat model has a row for every element and category pair" {
  each_threat_model "missing from" missing_rows
}

@test "each threat model has no row for anything outside its diagram" {
  each_threat_model "not in the diagram for" extra_rows
}

@test "a row claiming a status has the fields that status requires" {
  each_threat_model "row missing a required field in" incomplete_fields
}
