#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for when configure-truenas-secrets.sh writes A-01's API key. Both
# gcloud-touching helpers are replaced by stubs below.

# Fixtures below are inputs to the sourced script rather than to this file, so
# every assignment reads as a dead store from here.
# shellcheck disable=SC2034

setup() {
  # shellcheck source=configure-truenas-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-truenas-secrets.sh"

  POPULATED=""
  STORE="${BATS_TEST_TMPDIR}/store"

  # shellcheck disable=SC2329
  secret_is_populated() { [[ -n ${POPULATED} ]]; }

  # shellcheck disable=SC2329
  add_secret_version() {
    {
      printf '%s:' "${1}"
      cat
    } >>"${STORE}"
  }
}

stored() { cat "${STORE}" 2>/dev/null || true; }

@test "a populated secret is left alone when no key is supplied" {
  POPULATED=yes
  run ensure_api_key ""
  [[ ${status} -eq 0 ]]
  [[ ${output} == "truenas-api-key already set." ]]
  [[ -z "$(stored)" ]]
}

@test "a supplied key overwrites a populated secret" {
  POPULATED=yes
  ensure_api_key 1-rotated
  [[ "$(stored)" == 'truenas-api-key:1-rotated' ]]
}

@test "a supplied key is stored with no trailing newline" {
  ensure_api_key 1-abc
  [[ "$(stored)" == 'truenas-api-key:1-abc' ]]
}

@test "a key carrying whitespace is rejected" {
  run ensure_api_key '1-abc extra'
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"must not contain whitespace"* ]]
  [[ -z "$(stored)" ]]
}

@test "an empty key skips rather than prompting when stdin is not a terminal" {
  run ensure_api_key ""
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving truenas-api-key empty"* ]]
  [[ -z "$(stored)" ]]
}
