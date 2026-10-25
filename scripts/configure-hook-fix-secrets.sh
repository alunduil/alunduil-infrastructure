#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the hook-fix GitHub App's ID and private key in the Secret Manager
# shells terraform/bootstrap/hook_fix.tf declares. Re-running prompts only for
# an empty secret. A supplied value overwrites the stored one, which is how a
# key is rotated.

set -euo pipefail

# shellcheck source=scripts/lib/secret-manager.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/secret-manager.sh"

APP_NAME="alunduil-hook-fix"
SETUP_DOC="docs/how-to/create-hook-fix-github-app.md"

die() {
  echo "error: $*" >&2
  exit 1
}

needs_write() {
  local secret="$1" supplied="$2"
  [[ -n ${supplied} ]] || ! secret_is_populated "${secret}"
}

# read prompts on stderr, so only the answer reaches stdout.
answer_for() {
  local prompt="$1" value="$2"
  [[ -n ${value} ]] || read -r -p "${prompt} (Enter to skip): " value
  printf '%s' "${value}"
}

check_app_id() {
  # A wrong ID surfaces only when the first fix push is refused, so catch a
  # mistyped one here.
  [[ ${1} =~ ^[0-9]+$ ]] || die "App ID must be digits, got '${1}'"
  printf '%s' "${1}"
}

read_private_key() {
  # A path typed at the prompt arrives with its tilde unexpanded.
  local path="${1/#\~/${HOME}}"

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

# transform validates the answer and prints the bytes to store. It runs before
# the write rather than piping into it, so a rejected answer stores nothing.
ensure_secret() {
  local secret="$1" prompt="$2" supplied="$3" transform="$4"

  needs_write "${secret}" "${supplied}" || {
    echo "${secret} already set."
    return 0
  }

  [[ -n ${supplied} ]] || announce_app_once

  local value
  value="$(answer_for "${prompt}" "${supplied}")"
  [[ -n ${value} ]] || {
    echo "Leaving ${secret} empty; see ${SETUP_DOC}" >&2
    return 0
  }

  value="$("${transform}" "${value}")" || return
  printf '%s' "${value}" | add_secret_version "${secret}"
}

# Skip the executable body when sourced (e.g. by
# configure-hook-fix-secrets.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

ensure_secret hook-fix-app-id "${APP_NAME} App ID" \
  "${HOOK_FIX_APP_ID:-}" check_app_id
ensure_secret hook-fix-app-private-key "Path to the ${APP_NAME} private key .pem" \
  "${HOOK_FIX_APP_PRIVATE_KEY_FILE:-}" read_private_key
