#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the sourceable helpers in configure-grafana-github-secrets.sh. The
# Secret Manager calls are exercised by running the script against the live
# project.

# Fixtures below are inputs to the sourced script rather than to this file, so
# every assignment reads as a dead store from here.
# shellcheck disable=SC2034

setup() {
  unset GRAFANA_GITHUB_APP_ID GRAFANA_GITHUB_APP_INSTALLATION_ID GRAFANA_GITHUB_APP_PRIVATE_KEY_FILE
  # shellcheck source=configure-grafana-github-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-grafana-github-secrets.sh"

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

# --- needs_write ----------------------------------------------------------

@test "needs_write is true when the secret is empty" {
  run needs_write grafana-github-app-id ""
  [[ ${status} -eq 0 ]]
}

@test "needs_write is false when the secret holds a value" {
  touch "${BATS_TEST_TMPDIR}/populated-grafana-github-app-id"
  run needs_write grafana-github-app-id ""
  [[ ${status} -eq 1 ]]
}

@test "needs_write is true for a supplied value over a populated secret" {
  touch "${BATS_TEST_TMPDIR}/populated-grafana-github-app-id"
  run needs_write grafana-github-app-id "12345"
  [[ ${status} -eq 0 ]]
}

# --- answer_for -----------------------------------------------------------

@test "answer_for returns a supplied value without prompting" {
  result="$(answer_for "App ID" 12345 </dev/null)"
  [[ ${result} == "12345" ]]
}

@test "answer_for returns what the operator types" {
  result="$(answer_for "App ID" "" <<<"67890" 2>/dev/null)"
  [[ ${result} == "67890" ]]
}

# --- check_digits ---------------------------------------------------------

@test "check_digits passes digits through" {
  result="$(check_digits 12345)"
  [[ ${result} == "12345" ]]
}

@test "check_digits rejects a value that isn't digits" {
  run check_digits alunduil-grafana-github
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"expected digits"* ]]
}

# --- read_private_key -----------------------------------------------------

@test "read_private_key emits a PEM file's contents" {
  keyfile="${BATS_TEST_TMPDIR}/key.pem"
  printf -- '-----BEGIN RSA PRIVATE KEY-----\nBODY\n' >"${keyfile}" # pragma: allowlist secret
  result="$(read_private_key "${keyfile}")"
  [[ ${result} == *"BODY"* ]]
}

@test "read_private_key expands a leading ~ to HOME" {
  HOME="${BATS_TEST_TMPDIR}"
  printf -- '-----BEGIN PRIVATE KEY-----\n' >"${BATS_TEST_TMPDIR}/id.pem" # pragma: allowlist secret
  # A literal quoted tilde here would trip shellcheck's SC2088.
  tilde='~'
  run read_private_key "${tilde}/id.pem"
  [[ ${status} -eq 0 ]]
}

@test "read_private_key errors on an unreadable path" {
  run read_private_key "${BATS_TEST_TMPDIR}/does-not-exist.pem"
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"cannot read"* ]]
}

@test "read_private_key rejects a file that isn't a PEM private key" {
  keyfile="${BATS_TEST_TMPDIR}/not-a-key.pem"
  printf 'hello' >"${keyfile}"
  run read_private_key "${keyfile}"
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"not a PEM private key"* ]]
}

# --- ensure_secret --------------------------------------------------------

@test "ensure_secret neither prompts nor writes a populated secret" {
  touch "${BATS_TEST_TMPDIR}/populated-grafana-github-app-id"
  run ensure_secret grafana-github-app-id "App ID" "" record_transform </dev/null
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"already set"* ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/transformed" ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/writes" ]]
}

@test "ensure_secret stores the transformed answer in an empty secret" {
  run ensure_secret grafana-github-app-id "App ID" "" record_transform <<<"typed"
  [[ ${status} -eq 0 ]]
  [[ $(cat "${BATS_TEST_TMPDIR}/transformed") == "typed" ]]
  [[ $(cat "${BATS_TEST_TMPDIR}/writes") == "add grafana-github-app-id STORED" ]]
}

@test "ensure_secret overwrites a populated secret with a supplied value" {
  touch "${BATS_TEST_TMPDIR}/populated-grafana-github-app-id"
  run ensure_secret grafana-github-app-id "App ID" "12345" record_transform </dev/null
  [[ $(cat "${BATS_TEST_TMPDIR}/transformed") == "12345" ]]
  [[ $(cat "${BATS_TEST_TMPDIR}/writes") == "add grafana-github-app-id STORED" ]]
}

@test "ensure_secret writes nothing when the operator skips the prompt" {
  run ensure_secret grafana-github-app-id "App ID" "" record_transform <<<""
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving grafana-github-app-id empty"* ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/transformed" ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/writes" ]]
}

@test "ensure_secret writes nothing when the transform rejects the answer" {
  run ensure_secret grafana-github-app-id "App ID" "not-digits" check_digits </dev/null
  [[ ${status} -ne 0 ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/writes" ]]
}
