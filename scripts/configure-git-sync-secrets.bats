#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the resolve-once behaviour in configure-git-sync-secrets.sh:
# what makes it skip, what it rejects, and the exact bytes it stores. The two
# gcloud-touching helpers are replaced by stubs below — Secret Manager is
# covered by the bootstrap run itself.

setup() {
  # shellcheck source=configure-git-sync-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-git-sync-secrets.sh"

  POPULATED=""
  ADDED="${BATS_TEST_TMPDIR}/added"

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
    } >>"${ADDED}"
  }
}

added() { cat "${ADDED}" 2>/dev/null || true; }

pem() {
  local path="${BATS_TEST_TMPDIR}/key.pem"
  printf -- '-----BEGIN RSA PRIVATE KEY-----\nAAAA\n-----END RSA PRIVATE KEY-----\n' >"${path}" # pragma: allowlist secret
  echo "${path}"
}

# --- ensure_identifier ----------------------------------------------------

@test "ensure_identifier leaves a populated secret alone" {
  POPULATED="grafana-git-sync-app-id"
  run ensure_identifier grafana-git-sync-app-id "App ID" 1234
  [[ ${status} -eq 0 ]]
  [[ ${output} == "grafana-git-sync-app-id already set." ]]
  [[ -z "$(added)" ]]
}

@test "ensure_identifier stores the supplied value with no trailing newline" {
  ensure_identifier grafana-git-sync-app-id "App ID" 1234
  [[ "$(added)" == 'grafana-git-sync-app-id:1234' ]]
}

@test "ensure_identifier rejects a non-numeric value" {
  run ensure_identifier grafana-git-sync-app-id "App ID" 'Iv1.abc'
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"App ID must be digits, got 'Iv1.abc'"* ]]
  [[ -z "$(added)" ]]
}

@test "ensure_identifier skips rather than prompting when stdin is not a terminal" {
  run ensure_identifier grafana-git-sync-app-id "App ID" ""
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving grafana-git-sync-app-id empty"* ]]
  [[ -z "$(added)" ]]
}

# --- ensure_private_key ---------------------------------------------------

@test "ensure_private_key leaves a populated secret alone" {
  POPULATED="grafana-git-sync-app-private-key"
  GIT_SYNC_APP_PRIVATE_KEY_FILE="$(pem)"
  run ensure_private_key grafana-git-sync-app-private-key
  [[ ${status} -eq 0 ]]
  [[ ${output} == "grafana-git-sync-app-private-key already set." ]]
  [[ -z "$(added)" ]]
}

@test "ensure_private_key stores the PEM verbatim" {
  GIT_SYNC_APP_PRIVATE_KEY_FILE="$(pem)"
  ensure_private_key grafana-git-sync-app-private-key
  [[ "$(added)" == "grafana-git-sync-app-private-key:$(cat "${GIT_SYNC_APP_PRIVATE_KEY_FILE}")" ]]
}

@test "ensure_private_key expands a leading tilde" {
  pem >/dev/null
  HOME="${BATS_TEST_TMPDIR}"
  # A literal tilde is the point: it stands in for what read hands back when an
  # operator types the path at the prompt.
  # shellcheck disable=SC2088
  GIT_SYNC_APP_PRIVATE_KEY_FILE="~/key.pem"
  ensure_private_key grafana-git-sync-app-private-key
  [[ "$(added)" == *'BEGIN RSA PRIVATE KEY'* ]] # pragma: allowlist secret
}

@test "ensure_private_key rejects a file that is not a PEM key" {
  GIT_SYNC_APP_PRIVATE_KEY_FILE="${BATS_TEST_TMPDIR}/notes.txt"
  echo "just some text" >"${GIT_SYNC_APP_PRIVATE_KEY_FILE}"
  run ensure_private_key grafana-git-sync-app-private-key
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"is not a PEM private key"* ]]
  [[ -z "$(added)" ]]
}

@test "ensure_private_key rejects an unreadable path" {
  GIT_SYNC_APP_PRIVATE_KEY_FILE="${BATS_TEST_TMPDIR}/missing.pem"
  run ensure_private_key grafana-git-sync-app-private-key
  [[ ${status} -eq 1 ]]
  [[ ${output} == *"cannot read"* ]]
  [[ -z "$(added)" ]]
}

@test "ensure_private_key skips rather than prompting when stdin is not a terminal" {
  GIT_SYNC_APP_PRIVATE_KEY_FILE=""
  run ensure_private_key grafana-git-sync-app-private-key
  [[ ${status} -eq 0 ]]
  [[ ${output} == *"Leaving grafana-git-sync-app-private-key empty"* ]]
  [[ -z "$(added)" ]]
}
