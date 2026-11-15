#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for what configure-truenas-secrets.sh adds to ensure_secret.
# lib/secret-manager.bats covers when a secret is written.

setup() {
  # shellcheck source=configure-truenas-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-truenas-secrets.sh"
}

@test "an API key passes through unchanged" {
  result="$(check_no_whitespace 1-abc)"
  [[ ${result} == "1-abc" ]]
}

@test "an API key carrying whitespace is rejected" {
  run check_no_whitespace '1-abc extra'
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"must not contain whitespace"* ]]
}
