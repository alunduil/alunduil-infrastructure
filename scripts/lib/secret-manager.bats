#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for ensure_secret in secret-manager.sh. The Secret Manager calls
# are exercised by running a configure-*-secrets.sh script against the live
# project.

# Fixtures below are inputs to the sourced library rather than to this file, so
# every assignment reads as a dead store from here.
# shellcheck disable=SC2034

setup() {
  SETUP_DOC="docs/how-to/create-example.md"
  # shellcheck source=secret-manager.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/secret-manager.sh"

  # Secret Manager stand-ins, defined after the source so they replace the
  # shared helpers. A marker file marks a secret populated, and each write is
  # logged with its bytes.
  # shellcheck disable=SC2329 # called indirectly by needs_write
  secret_is_populated() { [[ -e "${BATS_TEST_TMPDIR}/populated-${1}" ]]; }
  # shellcheck disable=SC2329 # called indirectly by ensure_secret
  add_secret_version() { echo "add ${1} $(cat)" >>"${BATS_TEST_TMPDIR}/writes"; }
}

# Logs to a file because the transform runs in a command substitution, whose
# variables don't survive it.
# shellcheck disable=SC2329 # called indirectly by ensure_secret
record_transform() {
  echo "${1}" >>"${BATS_TEST_TMPDIR}/transformed"
  printf 'STORED'
}

# shellcheck disable=SC2329 # called indirectly by ensure_secret
reject() { die "rejected '${1}'"; }

# --- needs_write ----------------------------------------------------------

@test "needs_write is true when the secret is empty" {
  run needs_write example-id ""
  [[ ${status} -eq 0 ]]
}

@test "needs_write is false when the secret holds a value" {
  touch "${BATS_TEST_TMPDIR}/populated-example-id"
  run needs_write example-id ""
  [[ ${status} -eq 1 ]]
}

@test "needs_write is true for a supplied value over a populated secret" {
  touch "${BATS_TEST_TMPDIR}/populated-example-id"
  run needs_write example-id "12345"
  [[ ${status} -eq 0 ]]
}

# --- answer_for -----------------------------------------------------------

@test "answer_for returns a supplied value without prompting" {
  result="$(answer_for "ID" 12345 </dev/null)"
  [[ ${result} == "12345" ]]
}

@test "answer_for returns what the operator types" {
  result="$(answer_for "ID" "" <<<"67890" 2>/dev/null)"
  [[ ${result} == "67890" ]]
}

@test "answer_for asks through a caller's read_answer" {
  # shellcheck disable=SC2329 # called indirectly by answer_for
  read_answer() { printf 'from-override'; }
  result="$(answer_for "ID" "" </dev/null)"
  [[ ${result} == "from-override" ]]
}

# --- ensure_secret --------------------------------------------------------

@test "ensure_secret neither prompts nor writes a populated secret" {
  touch "${BATS_TEST_TMPDIR}/populated-example-id"
  run ensure_secret example-id "ID" "" record_transform </dev/null
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"already set"* ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/transformed" ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/writes" ]]
}

@test "ensure_secret stores the transformed answer in an empty secret" {
  run ensure_secret example-id "ID" "" record_transform <<<"typed"
  [[ ${status} -eq 0 ]]
  [[ $(cat "${BATS_TEST_TMPDIR}/transformed") == "typed" ]]
  [[ $(cat "${BATS_TEST_TMPDIR}/writes") == "add example-id STORED" ]]
}

@test "ensure_secret overwrites a populated secret with a supplied value" {
  touch "${BATS_TEST_TMPDIR}/populated-example-id"
  run ensure_secret example-id "ID" "12345" record_transform </dev/null
  [[ $(cat "${BATS_TEST_TMPDIR}/transformed") == "12345" ]]
  [[ $(cat "${BATS_TEST_TMPDIR}/writes") == "add example-id STORED" ]]
}

@test "ensure_secret writes nothing when the operator skips the prompt" {
  run ensure_secret example-id "ID" "" record_transform <<<""
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving example-id empty; see docs/how-to/create-example.md"* ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/transformed" ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/writes" ]]
}

@test "ensure_secret writes nothing when the transform rejects the answer" {
  run ensure_secret example-id "ID" "bad" reject </dev/null
  [[ ${status} -ne 0 ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/writes" ]]
}
