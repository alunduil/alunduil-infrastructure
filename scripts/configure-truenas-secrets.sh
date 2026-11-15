#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the TrueNAS API key in the Secret Manager shell
# terraform/bootstrap/truenas.tf declares. Supplying TRUENAS_API_KEY rotates
# it.

set -euo pipefail

# shellcheck source=scripts/lib/secret-manager.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/secret-manager.sh"

# shellcheck disable=SC2034 # read by lib/secret-manager.sh
SETUP_DOC="docs/how-to/apply-terraform-to-truenas.md"

read_answer() {
  local value
  read -r -s -p "${1} (input hidden, Enter to skip): " value
  echo >&2
  printf '%s' "${value}"
}

check_no_whitespace() {
  [[ ${1} != *[[:space:]]* ]] || die "the API key must not contain whitespace"
  printf '%s' "${1}"
}

# Skip the executable body when sourced (e.g. by
# configure-truenas-secrets.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

ensure_secret truenas-api-key "TrueNAS API key" \
  "${TRUENAS_API_KEY:-}" check_no_whitespace
