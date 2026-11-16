#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the Gmail app password in the Secret Manager shell
# terraform/bootstrap/nanopi_neo3.tf declares. Supplying GMAIL_APP_PASSWORD
# rotates it.

set -euo pipefail

# shellcheck source=scripts/lib/secret-manager.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/secret-manager.sh"

# shellcheck disable=SC2034 # read by lib/secret-manager.sh
SETUP_DOC="docs/how-to/configure-the-nanopi-neo3.md"

read_answer() {
  local value
  read -r -s -p "${1} (input hidden, Enter to skip): " value
  echo >&2
  printf '%s' "${value}"
}

# Google displays the password in groups of four; Exim needs it unbroken.
strip_spaces() {
  printf '%s' "${1// /}"
}

# Skip the executable body when sourced (e.g. by
# configure-nanopi-neo3-secrets.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

ensure_secret gmail-app-password-nanopi-neo3 "Gmail app password for the NanoPi-NEO3" \
  "${GMAIL_APP_PASSWORD:-}" strip_spaces
