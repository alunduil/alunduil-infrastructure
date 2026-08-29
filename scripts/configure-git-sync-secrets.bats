#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the resolve-once behaviour in configure-git-sync-secrets.sh:
# what makes it skip, what it rejects, the exact bytes it stores, and when the
# operator gets told which App is meant. load_populated and add_secret_version
# are the only gcloud-touching helpers; the first is fed through `populated`
# and the second stubbed, so Secret Manager is left to the bootstrap run.

# Fixtures below are inputs to the sourced script rather than to this file, so
# every assignment reads as a dead store from here.
# shellcheck disable=SC2034

setup() {
  # shellcheck source=configure-git-sync-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-git-sync-secrets.sh"

  populated=""
  STORE="${BATS_TEST_TMPDIR}/store"
  GIT_SYNC_APP_ID=""
  GIT_SYNC_APP_INSTALLATION_ID=""
  GIT_SYNC_APP_PRIVATE_KEY_FILE=""

  # Records the secret name and the bytes on stdin, so a test can assert both
  # that a write happened and what it carried. Reached only from the sourced
  # script, which shellcheck cannot see.
  # shellcheck disable=SC2329
  add_secret_version() {
    {
      printf '%s:' "${1}"
      cat
      printf '\n'
    } >>"${STORE}"
  }
}

all_populated() { populated="${GIT_SYNC_SECRETS[*]}"; }

stored() { cat "${STORE}" 2>/dev/null || true; }

refute_stored() { [[ -z "$(stored)" ]]; }

pem_fixture() {
  local path="${BATS_TEST_TMPDIR}/key.pem"
  printf -- '-----BEGIN RSA PRIVATE KEY-----\nAAAA\n-----END RSA PRIVATE KEY-----\n' >"${path}" # pragma: allowlist secret
  echo "${path}"
}

# --- any_prompt_pending ---------------------------------------------------
#
# Gates the pointer naming which of several similarly-named Apps is meant, so
# it has to stay quiet on the paths where nobody is about to be asked.

@test "any_prompt_pending is false once every secret holds a value" {
  all_populated
  run any_prompt_pending
  [[ ${status} -eq 1 ]]
}

@test "any_prompt_pending is false when the environment supplies what is missing" {
  GIT_SYNC_APP_ID=4257071
  GIT_SYNC_APP_INSTALLATION_ID=145465865
  GIT_SYNC_APP_PRIVATE_KEY_FILE="$(pem_fixture)"
  run any_prompt_pending
  [[ ${status} -eq 1 ]]
}

@test "any_prompt_pending is true for a value neither stored nor supplied" {
  populated="grafana-git-sync-app-id grafana-git-sync-app-private-key"
  run any_prompt_pending
  [[ ${status} -eq 0 ]]
}

@test "the pointer names the property that separates this App from the others" {
  run print_git_sync_app_pointer
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"installed on alunduil-infrastructure alone"* ]]
}

# --- ensure_identifier ----------------------------------------------------

@test "ensure_identifier leaves a populated secret alone" {
  populated="grafana-git-sync-app-id"
  run ensure_identifier grafana-git-sync-app-id "App ID" 1234
  [[ ${status} -eq 0 ]]
  [[ ${output} == "grafana-git-sync-app-id already set." ]]
  refute_stored
}

@test "ensure_identifier stores the supplied value with no trailing newline" {
  ensure_identifier grafana-git-sync-app-id "App ID" 1234
  [[ "$(stored)" == 'grafana-git-sync-app-id:1234' ]]
}

@test "ensure_identifier rejects a non-numeric value" {
  run ensure_identifier grafana-git-sync-app-id "App ID" 'Iv1.abc'
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"App ID must be digits, got 'Iv1.abc'"* ]]
  refute_stored
}

@test "ensure_identifier skips rather than prompting when stdin is not a terminal" {
  run ensure_identifier grafana-git-sync-app-id "App ID" ""
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving grafana-git-sync-app-id empty"* ]]
  refute_stored
}

# --- ensure_private_key ---------------------------------------------------

@test "ensure_private_key leaves a populated secret alone" {
  populated="grafana-git-sync-app-private-key"
  GIT_SYNC_APP_PRIVATE_KEY_FILE="$(pem_fixture)"
  run ensure_private_key grafana-git-sync-app-private-key
  [[ ${status} -eq 0 ]]
  [[ ${output} == "grafana-git-sync-app-private-key already set." ]]
  refute_stored
}

@test "ensure_private_key stores the PEM verbatim" {
  GIT_SYNC_APP_PRIVATE_KEY_FILE="$(pem_fixture)"
  ensure_private_key grafana-git-sync-app-private-key
  [[ "$(stored)" == "grafana-git-sync-app-private-key:$(cat "${GIT_SYNC_APP_PRIVATE_KEY_FILE}")" ]]
}

@test "ensure_private_key expands a leading tilde" {
  pem_fixture >/dev/null
  HOME="${BATS_TEST_TMPDIR}"
  # A literal tilde is the point: it stands in for what read hands back when an
  # operator types the path at the prompt.
  # shellcheck disable=SC2088
  GIT_SYNC_APP_PRIVATE_KEY_FILE="~/key.pem"
  ensure_private_key grafana-git-sync-app-private-key
  [[ "$(stored)" == *'BEGIN RSA PRIVATE KEY'* ]] # pragma: allowlist secret
}

@test "ensure_private_key rejects a file that is not a PEM key" {
  GIT_SYNC_APP_PRIVATE_KEY_FILE="${BATS_TEST_TMPDIR}/notes.txt"
  echo "just some text" >"${GIT_SYNC_APP_PRIVATE_KEY_FILE}"
  run ensure_private_key grafana-git-sync-app-private-key
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"is not a PEM private key"* ]]
  refute_stored
}

@test "ensure_private_key rejects an unreadable path" {
  GIT_SYNC_APP_PRIVATE_KEY_FILE="${BATS_TEST_TMPDIR}/missing.pem"
  run ensure_private_key grafana-git-sync-app-private-key
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"cannot read"* ]]
  refute_stored
}

@test "ensure_private_key skips rather than prompting when stdin is not a terminal" {
  GIT_SYNC_APP_PRIVATE_KEY_FILE=""
  run ensure_private_key grafana-git-sync-app-private-key
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving grafana-git-sync-app-private-key empty"* ]]
  refute_stored
}
