#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for app-secrets.sh. secret-manager.bats covers ensure_secret.

# Fixtures below are inputs to the sourced library rather than to this file, so
# every assignment reads as a dead store from here.
# shellcheck disable=SC2034

setup() {
  APP_NAME="example-app"
  SETUP_DOC="docs/how-to/create-example-app.md"
  # shellcheck source=app-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/app-secrets.sh"

  # Secret Manager stand-ins, defined after the source so they replace the
  # shared helpers.
  # shellcheck disable=SC2329 # called indirectly by needs_write
  secret_is_populated() { false; }
  # shellcheck disable=SC2329 # called indirectly by ensure_secret
  add_secret_version() { cat >/dev/null; }
}

# --- check_digits ---------------------------------------------------------

@test "check_digits passes digits through" {
  result="$(check_digits 12345)"
  [[ ${result} == "12345" ]]
}

@test "check_digits rejects a value that isn't digits" {
  run check_digits example-app
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

# --- announce_pointer -----------------------------------------------------

@test "ensure_secret names the caller's App and setup doc before prompting" {
  run ensure_secret example-app-id "App ID" "" check_digits <<<""
  [[ ${output} == *"named example-app"* ]]
  [[ ${output} == *"see docs/how-to/create-example-app.md"* ]]
}

# Redirection, not $(...) or run: either runs the call in a subshell, where the
# flag cannot survive and the test would fail whatever the code does.
@test "the App pointer is printed once across prompts" {
  announce_pointer 2>"${BATS_TEST_TMPDIR}/first"
  announce_pointer 2>"${BATS_TEST_TMPDIR}/second"
  grep -q "named example-app" "${BATS_TEST_TMPDIR}/first"
  [[ ! -s "${BATS_TEST_TMPDIR}/second" ]]
}
