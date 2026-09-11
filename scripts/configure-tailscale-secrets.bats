#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the resolve-once behaviour in configure-tailscale-secrets.sh:
# what makes it skip, what it rejects, the exact bytes it stores, and when the
# operator gets told which client is meant. Both gcloud-touching helpers are
# replaced by stubs below, so Secret Manager is left to the bootstrap run.

# Fixtures below are inputs to the sourced script rather than to this file, so
# every assignment reads as a dead store from here.
# shellcheck disable=SC2034

setup() {
  # shellcheck source=configure-tailscale-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-tailscale-secrets.sh"

  POPULATED=""
  STORE="${BATS_TEST_TMPDIR}/store"
  TAILSCALE_OAUTH_CLIENT_ID=""
  TAILSCALE_OAUTH_CLIENT_SECRET=""

  # Both stubs are reached only from the sourced script, which shellcheck
  # cannot see.
  # shellcheck disable=SC2329
  secret_is_populated() { [[ " ${POPULATED} " == *" ${1} "* ]]; }

  # Records the secret name and the bytes on stdin, so a test can assert both
  # that a write happened and what it carried.
  # shellcheck disable=SC2329
  add_secret_version() {
    {
      printf '%s:' "${1}"
      cat
      printf '\n'
    } >>"${STORE}"
  }
}

stored() { cat "${STORE}" 2>/dev/null || true; }

refute_stored() { [[ -z "$(stored)" ]]; }

# --- the client pointer ---------------------------------------------------
#
# Names which client the two values have to come from, so it has to reach the
# operator exactly once, and only where somebody is about to be asked.

@test "the pointer says both values come from one client and the secret is shown once" {
  run print_oauth_client_pointer
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"belong to one OAuth client"* ]]
  [[ ${output} == *"shown only when"* ]]
}

# Redirection, not $(...) or run: either runs the call in a subshell, where the
# flag cannot survive and the test would fail whatever the code does.
@test "announce_client_once speaks the first time and stays quiet after" {
  announce_client_once 2>"${BATS_TEST_TMPDIR}/first"
  announce_client_once 2>"${BATS_TEST_TMPDIR}/second"
  grep -q "one OAuth client" "${BATS_TEST_TMPDIR}/first"
  [[ ! -s "${BATS_TEST_TMPDIR}/second" ]]
}

@test "a value supplied through the environment draws no pointer" {
  ensure_client_id tailscale-oauth-client-id "client ID" kPz9xQ2CNTRL \
    2>"${BATS_TEST_TMPDIR}/err"
  [[ ! -s "${BATS_TEST_TMPDIR}/err" ]]
}

# --- storing ---------------------------------------------------------------

@test "a populated secret is left alone" {
  POPULATED="tailscale-oauth-client-id"
  run ensure_client_id tailscale-oauth-client-id "client ID" kPz9xQ2CNTRL
  [[ ${status} -eq 0 ]]
  [[ ${output} == "tailscale-oauth-client-id already set." ]]
  refute_stored
}

@test "the supplied value is stored with no trailing newline" {
  ensure_client_id tailscale-oauth-client-id "client ID" kPz9xQ2CNTRL
  [[ "$(stored)" == 'tailscale-oauth-client-id:kPz9xQ2CNTRL' ]]
}

# The console hands over one opaque token per half; whitespace in either means
# the paste picked up a line break or a neighbouring field.
@test "a value carrying whitespace is rejected" {
  run ensure_client_secret tailscale-oauth-client-secret "client secret" \
    'tskey-client-abc def' # pragma: allowlist secret
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"must not contain whitespace"* ]]
  refute_stored
}

@test "both halves skip rather than prompting when stdin is not a terminal" {
  run ensure_client_id tailscale-oauth-client-id "client ID" ""
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving tailscale-oauth-client-id empty"* ]]

  run ensure_client_secret tailscale-oauth-client-secret "client secret" ""
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving tailscale-oauth-client-secret empty"* ]]

  refute_stored
}
