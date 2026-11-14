#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the hook-fix self-test GitHub App's ID and private key in the Secret
# Manager shells terraform/bootstrap/hook_fix_selftest.tf declares.

set -euo pipefail

APP_NAME="alunduil-hook-fix-selftest"
# shellcheck disable=SC2034 # read by lib/app-secrets.sh
SETUP_DOC="docs/how-to/create-hook-fix-selftest-github-app.md"

# shellcheck source=scripts/lib/app-secrets.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/app-secrets.sh"

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

ensure_secret hook-fix-selftest-app-id "${APP_NAME} App ID" \
  "${HOOK_FIX_SELFTEST_APP_ID:-}" check_digits
ensure_secret hook-fix-selftest-app-private-key "Path to the ${APP_NAME} private key .pem" \
  "${HOOK_FIX_SELFTEST_APP_PRIVATE_KEY_FILE:-}" read_private_key
