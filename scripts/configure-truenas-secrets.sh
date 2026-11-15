#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates A-01's API key in the Secret Manager shell
# terraform/bootstrap/truenas.tf declares. Re-running prompts only while the
# secret is empty. Supplying TRUENAS_API_KEY overwrites it, which is how the
# key is rotated.

set -euo pipefail

# shellcheck source=scripts/lib/secret-manager.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/secret-manager.sh"

SECRET="truenas-api-key" # pragma: allowlist secret
SETUP_DOC="docs/how-to/apply-terraform-to-truenas.md"

die() {
  echo "error: $*" >&2
  exit 1
}

ensure_api_key() {
  local value="${1}"

  if [[ -z ${value} ]] && secret_is_populated "${SECRET}"; then
    echo "${SECRET} already set."
    return
  fi

  if [[ -z ${value} && -t 0 ]]; then
    echo "The next value is A-01's API key. If it does not exist yet, see ${SETUP_DOC}." >&2
    read -r -s -p "TrueNAS API key (input hidden, Enter to skip): " value
    echo >&2
  fi

  [[ -n ${value} ]] || {
    echo "Leaving ${SECRET} empty; see ${SETUP_DOC}" >&2
    return
  }

  [[ ${value} != *[[:space:]]* ]] || die "the API key must not contain whitespace"

  # No trailing newline: the recipe exports the value as TRUENAS_API_KEY, and
  # a stray byte would fail authentication.
  printf '%s' "${value}" | add_secret_version "${SECRET}"
}

# Skip the executable body when sourced (e.g. by
# configure-truenas-secrets.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

ensure_api_key "${TRUENAS_API_KEY:-}"
