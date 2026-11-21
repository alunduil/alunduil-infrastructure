#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Read by the sourced library rather than by this file.
# shellcheck disable=SC2034

setup() {
  repo_root="${BATS_TEST_DIRNAME}/.."
  diagram="${repo_root}/docs/explanation/renovate-data-flow.md"
  model="${repo_root}/docs/explanation/threat-model-renovate.md"
  # shellcheck source=lib/threat-model.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/lib/threat-model.sh"
}

@test "the threat model has a row for every element and category pair" {
  local missing
  missing="$(missing_rows)"
  if [[ -n ${missing} ]]; then
    printf 'missing from %s:\n%s\n' "${model##*/}" "${missing}" >&2
    return 1
  fi
}

@test "the threat model has no row for anything outside the diagram" {
  local extra
  extra="$(extra_rows)"
  if [[ -n ${extra} ]]; then
    printf 'not required by %s:\n%s\n' "${diagram##*/}" "${extra}" >&2
    return 1
  fi
}

@test "a row claiming a status has the fields that status requires" {
  local bad
  bad="$(incomplete_rows)"
  if [[ -n ${bad} ]]; then
    printf 'row missing a required field:\n%s\n' "${bad}" >&2
    return 1
  fi
}
