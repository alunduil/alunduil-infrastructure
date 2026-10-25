#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the hook-fix GitHub App's ID and private key in the Secret Manager
# shells terraform/bootstrap/hook_fix.tf declares. Re-running prompts only for
# an empty secret; a supplied value overwrites, which is how a rotated key
# reaches the reusable workflow.

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-alunduil}"
APP_NAME="alunduil-hook-fix"
SETUP_DOC="docs/how-to/create-hook-fix-github-app.md"

die() {
  echo "error: $*" >&2
  exit 1
}

secret_is_populated() {
  local state
  state="$(gcloud secrets versions describe latest --secret "${1}" \
    --project "${PROJECT_ID}" --format='value(state)' 2>/dev/null || true)"

  [[ ${state} == "ENABLED" ]]
}

add_secret_version() {
  gcloud secrets versions add "${1}" --project "${PROJECT_ID}" --data-file=-
}

needs_write() {
  local secret="$1" supplied="$2"
  [[ -n ${supplied} ]] || ! secret_is_populated "${secret}"
}

resolve_app_id() {
  local value="${HOOK_FIX_APP_ID:-}"
  [[ -n ${value} ]] || read -r -p "${APP_NAME} App ID (Enter to skip): " value
  [[ -n ${value} ]] || return 0

  # A wrong ID surfaces only when the first fix push is refused, so catch a
  # mistyped one here.
  [[ ${value} =~ ^[0-9]+$ ]] || die "App ID must be digits, got '${value}'"
  printf '%s' "${value}"
}

resolve_app_private_key() {
  local path="${HOOK_FIX_APP_PRIVATE_KEY_FILE:-}"
  [[ -n ${path} ]] || read -r -p "Path to the ${APP_NAME} private key .pem (Enter to skip): " path
  [[ -n ${path} ]] || return 0

  # read hands back the tilde the shell would have expanded.
  path="${path/#\~/${HOME}}"

  [[ -r ${path} ]] || die "cannot read '${path}'"
  grep -q -- '-----BEGIN .*PRIVATE KEY-----' "${path}" \
    || die "'${path}' is not a PEM private key"
  cat "${path}"
}

pointer_shown=""

announce_app_once() {
  [[ -z ${pointer_shown} ]] || return 0

  pointer_shown=yes
  cat >&2 <<EOF

The next values belong to the GitHub App named ${APP_NAME}. If it does
not exist yet, see ${SETUP_DOC}.

EOF
}

ensure_secret() {
  local secret="$1" supplied="$2" resolve="$3"

  needs_write "${secret}" "${supplied}" || {
    echo "${secret} already set."
    return 0
  }

  [[ -n ${supplied} ]] || announce_app_once

  local value
  value="$("${resolve}")"
  [[ -n ${value} ]] || {
    echo "Leaving ${secret} empty; see ${SETUP_DOC}" >&2
    return 0
  }

  printf '%s' "${value}" | add_secret_version "${secret}"
}

# Skip the executable body when sourced (e.g. by
# configure-hook-fix-secrets.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

ensure_secret hook-fix-app-id "${HOOK_FIX_APP_ID:-}" resolve_app_id
ensure_secret hook-fix-app-private-key "${HOOK_FIX_APP_PRIVATE_KEY_FILE:-}" resolve_app_private_key
