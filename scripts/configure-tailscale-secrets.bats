#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the resolve-once behaviour in configure-tailscale-secrets.sh.
# Both gcloud-touching helpers are replaced by stubs below, so Secret Manager is
# left to the bootstrap run.

# Fixtures below are inputs to the sourced script rather than to this file, so
# every assignment reads as a dead store from here.
# shellcheck disable=SC2034

setup() {
  # shellcheck source=configure-tailscale-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-tailscale-secrets.sh"

  POPULATED=""
  STORE="${BATS_TEST_TMPDIR}/store"
  TAILSCALE_CLIENT_ID_RO=""
  TAILSCALE_CLIENT_ID_RW=""

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

# --- the credential pointer -------------------------------------------------
#
# The pointer has to say which credential is which — once, and only where
# somebody is about to be asked.

@test "the pointer says how to tell the two credentials apart" {
  run print_credential_pointer
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"trust-credentials"* ]]
  [[ ${output} == *"terraform plan"* ]]
  [[ ${output} == *"terraform apply"* ]]
}

# Redirection, not $(...) or run: either runs the call in a subshell, where the
# flag cannot survive and the test would fail whatever the code does.
@test "the pointer is printed once across both prompts" {
  announce_credentials_once 2>"${BATS_TEST_TMPDIR}/first"
  announce_credentials_once 2>"${BATS_TEST_TMPDIR}/second"
  grep -q "trust-credentials" "${BATS_TEST_TMPDIR}/first"
  [[ ! -s "${BATS_TEST_TMPDIR}/second" ]]
}

@test "a value supplied through the environment draws no pointer" {
  ensure_client_id tailscale-client-id-ro "client ID" kPz9xQ2CNTRL \
    2>"${BATS_TEST_TMPDIR}/err"
  [[ ! -s "${BATS_TEST_TMPDIR}/err" ]]
}

# --- storing ---------------------------------------------------------------

@test "a populated secret is left alone" {
  POPULATED="tailscale-client-id-ro"
  run ensure_client_id tailscale-client-id-ro "client ID" kPz9xQ2CNTRL
  [[ ${status} -eq 0 ]]
  [[ ${output} == "tailscale-client-id-ro already set." ]]
  refute_stored
}

# The two secrets resolve independently, so populating one must not skip the
# other — that would leave apply reaching for an empty client id.
@test "a populated read-only secret does not skip the read-write one" {
  POPULATED="tailscale-client-id-ro"
  ensure_client_id tailscale-client-id-rw "client ID" kRw7xQ2CNTRL
  [[ "$(stored)" == 'tailscale-client-id-rw:kRw7xQ2CNTRL' ]]
}

@test "the supplied value is stored with no trailing newline" {
  ensure_client_id tailscale-client-id-ro "client ID" kPz9xQ2CNTRL
  [[ "$(stored)" == 'tailscale-client-id-ro:kPz9xQ2CNTRL' ]]
}

@test "a value carrying whitespace is rejected" {
  run ensure_client_id tailscale-client-id-ro "client ID" 'kPz9xQ2CNTRL extra'
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"must not contain whitespace"* ]]
  refute_stored
}

@test "an empty value skips rather than prompting when stdin is not a terminal" {
  run ensure_client_id tailscale-client-id-ro "client ID" ""
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving tailscale-client-id-ro empty"* ]]
  refute_stored
}
