#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the pure helpers in configure-github-secrets.sh: the
# needs_*_prompt precedence and the resolve_* value/__KEEP__ handling. The
# network- and prompt-touching paths (gh, terraform, interactive read) are
# not exercised — they're covered by running the script against the live
# repo, which alunduil performs out-of-band.

# shellcheck disable=SC2034 # these globals are read by the sourced helpers
setup() {
  # has_secret / has_env_secret read the *_secrets globals and resolve_*
  # read the env inputs; reset both so each test starts from a clean state.
  existing_secrets=""
  existing_env_secrets=""
  unset GH_APP_ID GH_APP_PRIVATE_KEY_FILE GH_PROJECT_SYNC_TOKEN
  # shellcheck source=configure-github-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-github-secrets.sh"
}

# --- has_secret -----------------------------------------------------------

@test "has_secret matches a whole line" {
  existing_secrets=$'GH_APP_ID\nGH_APP_PRIVATE_KEY'
  run has_secret "GH_APP_ID"
  [[ ${status} -eq 0 ]]
}

@test "has_secret matches whole lines only, not substrings" {
  existing_secrets=$'GH_APP_ID_EXTRA\nOTHER'
  run has_secret "GH_APP_ID"
  [[ ${status} -eq 1 ]]
}

# --- needs_*_prompt -------------------------------------------------------

@test "needs_id_prompt is true when GH_APP_ID is unset and the secret is absent" {
  run needs_id_prompt
  [[ ${status} -eq 0 ]]
}

@test "needs_id_prompt is false when GH_APP_ID is supplied in the environment" {
  GH_APP_ID=98765
  run needs_id_prompt
  [[ ${status} -eq 1 ]]
}

@test "needs_id_prompt is false when the secret already exists" {
  existing_secrets=$'GH_APP_ID'
  run needs_id_prompt
  [[ ${status} -eq 1 ]]
}

@test "needs_key_prompt keys on GH_APP_PRIVATE_KEY_FILE and the GH_APP_PRIVATE_KEY secret" {
  run needs_key_prompt
  [[ ${status} -eq 0 ]]
  GH_APP_PRIVATE_KEY_FILE=/some/path.pem
  run needs_key_prompt
  [[ ${status} -eq 1 ]]
}

@test "needs_token_prompt keys on the environment-level secret list" {
  run needs_token_prompt
  [[ ${status} -eq 0 ]]
  existing_env_secrets=$'GH_PROJECT_SYNC_TOKEN'
  run needs_token_prompt
  [[ ${status} -eq 1 ]]
}

# --- resolve_gh_app_id ----------------------------------------------------

@test "resolve_gh_app_id returns the environment value when set" {
  GH_APP_ID=98765
  result="$(resolve_gh_app_id 2>/dev/null)"
  [[ ${result} == "98765" ]]
}

@test "resolve_gh_app_id keeps an existing repo secret" {
  existing_secrets=$'GH_APP_ID'
  result="$(resolve_gh_app_id 2>/dev/null)"
  [[ ${result} == "__KEEP__" ]]
}

# --- resolve_gh_app_private_key -------------------------------------------

@test "resolve_gh_app_private_key emits the contents of GH_APP_PRIVATE_KEY_FILE" {
  keyfile="${BATS_TEST_TMPDIR}/key.pem"
  printf 'PRIVATE-KEY-BODY' >"${keyfile}"
  GH_APP_PRIVATE_KEY_FILE="${keyfile}"
  result="$(resolve_gh_app_private_key 2>/dev/null)"
  [[ ${result} == "PRIVATE-KEY-BODY" ]]
}

@test "resolve_gh_app_private_key expands a leading ~ to HOME" {
  HOME="${BATS_TEST_TMPDIR}"
  printf 'HOME-KEY' >"${BATS_TEST_TMPDIR}/id.pem"
  # Build the ~ via a variable so the script under test does the expansion
  # (a literal quoted tilde here would just trip shellcheck's SC2088).
  tilde='~'
  GH_APP_PRIVATE_KEY_FILE="${tilde}/id.pem"
  result="$(resolve_gh_app_private_key 2>/dev/null)"
  [[ ${result} == "HOME-KEY" ]]
}

@test "resolve_gh_app_private_key errors on an unreadable path" {
  GH_APP_PRIVATE_KEY_FILE="${BATS_TEST_TMPDIR}/does-not-exist.pem"
  run resolve_gh_app_private_key
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"cannot read"* ]]
}

@test "resolve_gh_app_private_key keeps an existing repo secret" {
  existing_secrets=$'GH_APP_PRIVATE_KEY'
  result="$(resolve_gh_app_private_key 2>/dev/null)"
  [[ ${result} == "__KEEP__" ]]
}

# --- resolve_project_sync_token -------------------------------------------

@test "resolve_project_sync_token returns the environment value when set" {
  GH_PROJECT_SYNC_TOKEN=ghp_example
  result="$(resolve_project_sync_token 2>/dev/null)"
  [[ ${result} == "ghp_example" ]]
}

@test "resolve_project_sync_token keeps an existing environment secret" {
  existing_env_secrets=$'GH_PROJECT_SYNC_TOKEN'
  result="$(resolve_project_sync_token 2>/dev/null)"
  [[ ${result} == "__KEEP__" ]]
}
