#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the deployer GitHub Apps' IDs and private keys in the Secret Manager
# shells terraform/bootstrap/deployer_github_app.tf declares.

set -euo pipefail

# shellcheck disable=SC2034 # read by lib/app-secrets.sh
SETUP_DOC="docs/how-to/create-deployer-github-app.md"

# shellcheck source=scripts/lib/app-secrets.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/app-secrets.sh"

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

# The two Apps differ only by their permissions, so each pair of prompts names
# its App. Swapping them hands plan the write key.
#
# The locals shadow the globals lib/app-secrets.sh reads, so each App gets its
# own name and its own once-only pointer.
configure_app() {
  local role="$1" id="$2" key_file="$3"
  # shellcheck disable=SC2034 # read by lib/app-secrets.sh
  local APP_NAME="$4" pointer_shown=""

  ensure_secret "deployer-github-app-id-${role}" "${APP_NAME} App ID" \
    "${id}" check_digits
  ensure_secret "deployer-github-app-private-key-${role}" \
    "Path to the ${APP_NAME} private key .pem" "${key_file}" read_private_key
}

configure_app ro "${DEPLOYER_GITHUB_APP_ID_RO:-}" \
  "${DEPLOYER_GITHUB_APP_PRIVATE_KEY_FILE_RO:-}" alunduil-infra-deployer-ro
configure_app rw "${DEPLOYER_GITHUB_APP_ID_RW:-}" \
  "${DEPLOYER_GITHUB_APP_PRIVATE_KEY_FILE_RW:-}" alunduil-infra-deployer
