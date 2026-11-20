#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the release gate App's private key in the Secret Manager shell
# terraform/bootstrap/release_gate.tf declares.

set -euo pipefail

APP_NAME="alunduil-release-gate"
# shellcheck disable=SC2034 # read by lib/app-secrets.sh
SETUP_DOC="docs/how-to/create-release-gate-github-app.md"

# shellcheck source=scripts/lib/app-secrets.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/app-secrets.sh"

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

ensure_secret release-gate-app-private-key "Path to the ${APP_NAME} private key .pem" \
  "${RELEASE_GATE_APP_PRIVATE_KEY_FILE:-}" read_private_key
