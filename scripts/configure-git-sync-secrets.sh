#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the Git Sync GitHub App credentials in the Secret Manager shells
# terraform/bootstrap/ declares. Each value is written once and never
# overwritten, so re-running is a no-op and the bootstrap layer stays editable
# without the .pem GitHub shows only once. Replacing a value goes through
# docs/how-to/rotate-git-sync-app-key.md.

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-alunduil}"
SETUP_DOC="docs/how-to/create-git-sync-github-app.md"

die() {
  echo "error: $*" >&2
  exit 1
}

# Secret Manager itself rather than a local sentinel: a version added by hand
# out of band counts as populated just as much as one this script wrote.
secret_is_populated() {
  local state
  state="$(gcloud secrets versions describe latest --secret "${1}" \
    --project "${PROJECT_ID}" --format='value(state)' 2>/dev/null || true)"

  [[ ${state} == "ENABLED" ]]
}

add_secret_version() {
  gcloud secrets versions add "${1}" --project "${PROJECT_ID}" --data-file=-
}

# Succeeds when the secret already holds a value, which is every caller's cue to
# leave it alone.
already_stored() {
  secret_is_populated "${1}" || return 1

  echo "${1} already set."
}

skip_notice() {
  echo "Leaving ${1} empty; see ${SETUP_DOC}" >&2
}

# Echoes the supplied value, else what the operator types, else nothing when
# there is no terminal to ask at. read prompts on stderr, so the answer is the
# only thing reaching stdout.
answer_for() {
  local prompt="${1}" value="${2}"

  if [[ -z ${value} && -t 0 ]]; then
    read -r -p "${prompt} (Enter to skip): " value
  fi

  printf '%s' "${value}"
}

ensure_identifier() {
  local secret="${1}" label="${2}" value="${3}"

  already_stored "${secret}" && return
  value="$(answer_for "${label}" "${value}")"
  [[ -n ${value} ]] || {
    skip_notice "${secret}"
    return
  }

  [[ ${value} =~ ^[0-9]+$ ]] || die "${label} must be digits, got '${value}'"

  # No trailing newline: consumers read the value straight into a TF_VAR, where
  # a stray byte would reach the Grafana connection resource.
  printf '%s' "${value}" | add_secret_version "${secret}"
}

ensure_private_key() {
  local secret="${1}" path="${GIT_SYNC_APP_PRIVATE_KEY_FILE:-}"

  already_stored "${secret}" && return
  path="$(answer_for "Path to the Git Sync App private key .pem" "${path}")"
  [[ -n ${path} ]] || {
    skip_notice "${secret}"
    return
  }

  # read hands back the tilde the shell would have expanded.
  path="${path/#\~/${HOME}}"

  [[ -r ${path} ]] || die "cannot read '${path}'"

  # Signing with the wrong bytes surfaces inside Grafana as an opaque
  # authentication failure, a long way from the paste that caused it.
  grep -q -- '-----BEGIN .*PRIVATE KEY-----' "${path}" \
    || die "'${path}' is not a PEM private key"

  add_secret_version "${secret}" <"${path}"
  echo "Shred ${path} once terraform/alunduil/ has applied."
}

# Skip the executable body when sourced (e.g. by
# configure-git-sync-secrets.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

# None of the three values exists until the App is registered, which is a
# browser action, so a run before that legitimately leaves the secrets empty.
ensure_identifier grafana-git-sync-app-id \
  "Git Sync App ID" "${GIT_SYNC_APP_ID:-}"
ensure_identifier grafana-git-sync-app-installation-id \
  "Git Sync App installation ID" "${GIT_SYNC_APP_INSTALLATION_ID:-}"
ensure_private_key grafana-git-sync-app-private-key
