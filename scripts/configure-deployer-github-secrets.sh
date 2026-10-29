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
APP_NAME="alunduil-infra-deployer-ro"
ensure_secret deployer-github-app-id-ro "${APP_NAME} App ID" \
  "${DEPLOYER_GITHUB_APP_ID_RO:-}" check_digits
ensure_secret deployer-github-app-private-key-ro "Path to the ${APP_NAME} private key .pem" \
  "${DEPLOYER_GITHUB_APP_PRIVATE_KEY_FILE_RO:-}" read_private_key

APP_NAME="alunduil-infra-deployer"
# shellcheck disable=SC2034 # read by lib/app-secrets.sh
pointer_shown=""
ensure_secret deployer-github-app-id-rw "${APP_NAME} App ID" \
  "${DEPLOYER_GITHUB_APP_ID_RW:-}" check_digits
ensure_secret deployer-github-app-private-key-rw "Path to the ${APP_NAME} private key .pem" \
  "${DEPLOYER_GITHUB_APP_PRIVATE_KEY_FILE_RW:-}" read_private_key
