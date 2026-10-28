#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the hook-fix GitHub App's ID and private key in the Secret Manager
# shells terraform/bootstrap/hook_fix.tf declares.

set -euo pipefail

APP_NAME="alunduil-hook-fix"
# shellcheck disable=SC2034 # read by lib/app-secrets.sh
SETUP_DOC="docs/how-to/create-hook-fix-github-app.md"

# shellcheck source=scripts/lib/app-secrets.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/app-secrets.sh"

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

ensure_secret hook-fix-app-id "${APP_NAME} App ID" \
  "${HOOK_FIX_APP_ID:-}" check_digits
ensure_secret hook-fix-app-private-key "Path to the ${APP_NAME} private key .pem" \
  "${HOOK_FIX_APP_PRIVATE_KEY_FILE:-}" read_private_key
