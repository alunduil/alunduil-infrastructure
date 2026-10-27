#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the Grafana GitHub data source App's ID, installation ID, and
# private key in the Secret Manager shells terraform/bootstrap/grafana_github.tf
# declares.

set -euo pipefail

APP_NAME="alunduil-grafana-github"
# shellcheck disable=SC2034 # read by lib/app-secrets.sh
SETUP_DOC="docs/how-to/create-grafana-github-app.md"

# shellcheck source=scripts/lib/app-secrets.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/app-secrets.sh"

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

ensure_secret grafana-github-app-id "${APP_NAME} App ID" \
  "${GRAFANA_GITHUB_APP_ID:-}" check_digits
ensure_secret grafana-github-app-installation-id "${APP_NAME} installation ID" \
  "${GRAFANA_GITHUB_APP_INSTALLATION_ID:-}" check_digits
ensure_secret grafana-github-app-private-key "Path to the ${APP_NAME} private key .pem" \
  "${GRAFANA_GITHUB_APP_PRIVATE_KEY_FILE:-}" read_private_key
