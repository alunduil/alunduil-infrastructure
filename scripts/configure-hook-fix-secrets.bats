#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the sourceable helpers in configure-hook-fix-secrets.sh. The
# Secret Manager calls and the interactive prompts are exercised by running the
# script against the live project.

# Fixtures below are inputs to the sourced script rather than to this file, so
# every assignment reads as a dead store from here.
# shellcheck disable=SC2034

setup() {
  unset HOOK_FIX_APP_ID HOOK_FIX_APP_PRIVATE_KEY_FILE
  # shellcheck source=configure-hook-fix-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-hook-fix-secrets.sh"

  # Stand-ins for Secret Manager, defined after the source so they replace the
  # script's: a secret is populated when its marker file exists, and each write
  # is logged with the bytes it would store.
  # shellcheck disable=SC2329 # called indirectly by needs_write
  secret_is_populated() { [[ -e "${BATS_TEST_TMPDIR}/populated-${1}" ]]; }
  # shellcheck disable=SC2329 # called indirectly by ensure_secret
  add_secret_version() { echo "add ${1} $(cat)" >>"${BATS_TEST_TMPDIR}/writes"; }
}

# Counts calls in a file: the resolver runs in a command substitution, whose
# variables don't survive it.
# shellcheck disable=SC2329 # called indirectly by ensure_secret
count_resolve() {
  echo x >>"${BATS_TEST_TMPDIR}/resolved"
  printf 'VALUE'
}

# shellcheck disable=SC2329 # called indirectly by ensure_secret
skip_resolve() { :; }

# --- needs_write ----------------------------------------------------------

@test "needs_write is true when the secret is empty" {
  run needs_write hook-fix-app-id ""
  [[ ${status} -eq 0 ]]
}

@test "needs_write is false when the secret holds a value" {
  touch "${BATS_TEST_TMPDIR}/populated-hook-fix-app-id"
  run needs_write hook-fix-app-id ""
  [[ ${status} -eq 1 ]]
}

@test "needs_write is true for a supplied value over a populated secret" {
  touch "${BATS_TEST_TMPDIR}/populated-hook-fix-app-id"
  run needs_write hook-fix-app-id "12345"
  [[ ${status} -eq 0 ]]
}

# --- resolve_app_id -------------------------------------------------------

@test "resolve_app_id returns the environment value when set" {
  HOOK_FIX_APP_ID=12345
  result="$(resolve_app_id)"
  [[ ${result} == "12345" ]]
}

@test "resolve_app_id rejects a value that isn't digits" {
  HOOK_FIX_APP_ID=alunduil-hook-fix
  run resolve_app_id
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"must be digits"* ]]
}

# --- resolve_app_private_key ----------------------------------------------

@test "resolve_app_private_key emits a PEM file's contents" {
  keyfile="${BATS_TEST_TMPDIR}/key.pem"
  printf -- '-----BEGIN RSA PRIVATE KEY-----\nBODY\n' >"${keyfile}" # pragma: allowlist secret
  HOOK_FIX_APP_PRIVATE_KEY_FILE="${keyfile}"
  result="$(resolve_app_private_key)"
  [[ ${result} == *"BODY"* ]]
}

@test "resolve_app_private_key expands a leading ~ to HOME" {
  HOME="${BATS_TEST_TMPDIR}"
  printf -- '-----BEGIN PRIVATE KEY-----\n' >"${BATS_TEST_TMPDIR}/id.pem" # pragma: allowlist secret
  # A literal quoted tilde here would trip shellcheck's SC2088.
  tilde='~'
  HOOK_FIX_APP_PRIVATE_KEY_FILE="${tilde}/id.pem"
  run resolve_app_private_key
  [[ ${status} -eq 0 ]]
}

@test "resolve_app_private_key errors on an unreadable path" {
  HOOK_FIX_APP_PRIVATE_KEY_FILE="${BATS_TEST_TMPDIR}/does-not-exist.pem"
  run resolve_app_private_key
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"cannot read"* ]]
}

@test "resolve_app_private_key rejects a file that isn't a PEM private key" {
  keyfile="${BATS_TEST_TMPDIR}/not-a-key.pem"
  printf 'hello' >"${keyfile}"
  HOOK_FIX_APP_PRIVATE_KEY_FILE="${keyfile}"
  run resolve_app_private_key
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"not a PEM private key"* ]]
}

# --- ensure_secret --------------------------------------------------------

@test "ensure_secret neither resolves nor writes a populated secret" {
  touch "${BATS_TEST_TMPDIR}/populated-hook-fix-app-id"
  run ensure_secret hook-fix-app-id "" count_resolve
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"already set"* ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/resolved" ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/writes" ]]
}

@test "ensure_secret writes the resolved value to an empty secret" {
  run ensure_secret hook-fix-app-id "" count_resolve
  [[ ${status} -eq 0 ]]
  [[ $(cat "${BATS_TEST_TMPDIR}/writes") == "add hook-fix-app-id VALUE" ]]
}

@test "ensure_secret overwrites a populated secret with a supplied value" {
  touch "${BATS_TEST_TMPDIR}/populated-hook-fix-app-id"
  run ensure_secret hook-fix-app-id "12345" count_resolve
  [[ $(cat "${BATS_TEST_TMPDIR}/writes") == "add hook-fix-app-id VALUE" ]]
}

@test "ensure_secret writes nothing when the operator skips the prompt" {
  run ensure_secret hook-fix-app-id "" skip_resolve
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving hook-fix-app-id empty"* ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/writes" ]]
}
