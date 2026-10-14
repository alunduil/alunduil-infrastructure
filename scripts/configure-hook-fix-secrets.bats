#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the sourceable helpers in configure-hook-fix-secrets.sh. The
# GraphQL listing and the interactive prompts are exercised by running the
# script against the live account.

# Fixtures below are inputs to the sourced script rather than to this file, so
# every assignment reads as a dead store from here.
# shellcheck disable=SC2034

setup() {
  unset HOOK_FIX_APP_ID HOOK_FIX_APP_PRIVATE_KEY_FILE
  # shellcheck source=configure-hook-fix-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-hook-fix-secrets.sh"
}

# Lets a test assert the command that was built rather than reaching GitHub.
# shellcheck disable=SC2329 # called indirectly by set_secret_on_repos
gh() { echo "gh $*"; }

# Counts calls in a file: the resolver runs in a command substitution, whose
# variables don't survive it.
# shellcheck disable=SC2329 # called indirectly by set_secret_on_repos
count_resolve() {
  echo x >>"${BATS_TEST_TMPDIR}/resolved"
  printf 'VALUE'
}

# --- needs_write ----------------------------------------------------------

@test "needs_write is true when the repo lacks the secret" {
  run needs_write HOOK_FIX_APP_ID "" $'OTHER\nHOOK_FIX_APP_ID_EXTRA'
  [[ ${status} -eq 0 ]]
}

@test "needs_write is false when the repo holds the secret" {
  run needs_write HOOK_FIX_APP_ID "" $'OTHER\nHOOK_FIX_APP_ID'
  [[ ${status} -eq 1 ]]
}

@test "needs_write is true for a supplied value the repo already holds" {
  run needs_write HOOK_FIX_APP_ID "12345" $'HOOK_FIX_APP_ID'
  [[ ${status} -eq 0 ]]
}

# --- will_prompt ----------------------------------------------------------

@test "will_prompt is true when a repo needs a value nobody supplied" {
  run will_prompt 1 ""
  [[ ${status} -eq 0 ]]
}

@test "will_prompt is false when the value is supplied or no repo needs it" {
  run will_prompt 1 "12345"
  [[ ${status} -eq 1 ]]
  run will_prompt 0 ""
  [[ ${status} -eq 1 ]]
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

# --- set_secret_on_repos --------------------------------------------------

# shellcheck disable=SC2329 # called indirectly by set_secret_on_repos
skip_resolve() { :; }

@test "set_secret_on_repos writes nothing when the operator skips the prompt" {
  run set_secret_on_repos HOOK_FIX_APP_ID skip_resolve owner/a
  [[ ${status} -eq 0 ]]
  [[ ${output} != *"gh secret set"* ]]
  [[ ${output} == *"Leaving HOOK_FIX_APP_ID unset"* ]]
}

@test "set_secret_on_repos resolves once for every repo" {
  run set_secret_on_repos HOOK_FIX_APP_ID count_resolve owner/a owner/b
  [[ ${output} == *"gh secret set HOOK_FIX_APP_ID --repo owner/a --body VALUE"* ]]
  [[ ${output} == *"gh secret set HOOK_FIX_APP_ID --repo owner/b --body VALUE"* ]]
  [[ $(wc -l <"${BATS_TEST_TMPDIR}/resolved") -eq 1 ]]
}

@test "set_secret_on_repos neither resolves nor writes without a repo" {
  run set_secret_on_repos HOOK_FIX_APP_ID count_resolve
  [[ ${output} != *"gh secret set"* ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/resolved" ]]
}
