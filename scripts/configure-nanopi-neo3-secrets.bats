#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the app password cleanup in configure-nanopi-neo3-secrets.sh.

setup() {
  # shellcheck source=configure-nanopi-neo3-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-nanopi-neo3-secrets.sh"
}

@test "an app password copied in groups loses its spaces" {
  result="$(strip_spaces 'abcd efgh ijkl mnop')"
  [[ ${result} == "abcdefghijklmnop" ]]
}

@test "an unbroken app password passes through unchanged" {
  result="$(strip_spaces abcdefghijklmnop)"
  [[ ${result} == "abcdefghijklmnop" ]]
}
