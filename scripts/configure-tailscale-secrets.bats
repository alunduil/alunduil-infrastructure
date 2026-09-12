#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the resolve-once behaviour in configure-tailscale-secrets.sh:
# what makes it skip, what it rejects, the exact bytes it stores, and when the
# operator gets told which credential is meant. Both gcloud-touching helpers are
# replaced by stubs below, so Secret Manager is left to the bootstrap run.

# Fixtures below are inputs to the sourced script rather than to this file, so
# every assignment reads as a dead store from here.
# shellcheck disable=SC2034

setup() {
  # shellcheck source=configure-tailscale-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-tailscale-secrets.sh"

  POPULATED=""
  STORE="${BATS_TEST_TMPDIR}/store"
  TAILSCALE_CLIENT_ID=""

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
# Names which credential the ID has to come from, and only reaches the operator
# where somebody is about to be asked.

@test "the pointer names the credential type and where it is listed" {
  run print_credential_pointer
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"OpenID Connect credential"* ]]
  [[ ${output} == *"trust-credentials"* ]]
}

@test "a value supplied through the environment draws no pointer" {
  ensure_client_id tailscale-client-id "client ID" kPz9xQ2CNTRL \
    2>"${BATS_TEST_TMPDIR}/err"
  [[ ! -s "${BATS_TEST_TMPDIR}/err" ]]
}

# --- storing ---------------------------------------------------------------

@test "a populated secret is left alone" {
  POPULATED="tailscale-client-id"
  run ensure_client_id tailscale-client-id "client ID" kPz9xQ2CNTRL
  [[ ${status} -eq 0 ]]
  [[ ${output} == "tailscale-client-id already set." ]]
  refute_stored
}

@test "the supplied value is stored with no trailing newline" {
  ensure_client_id tailscale-client-id "client ID" kPz9xQ2CNTRL
  [[ "$(stored)" == 'tailscale-client-id:kPz9xQ2CNTRL' ]]
}

@test "a value carrying whitespace is rejected" {
  run ensure_client_id tailscale-client-id "client ID" 'kPz9xQ2CNTRL extra'
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"must not contain whitespace"* ]]
  refute_stored
}

@test "an empty value skips rather than prompting when stdin is not a terminal" {
  run ensure_client_id tailscale-client-id "client ID" ""
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving tailscale-client-id empty"* ]]
  refute_stored
}
