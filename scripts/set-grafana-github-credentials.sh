#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Sets the read-only GitHub App's private key on the Grafana GitHub data source.
# The key never touches disk.
#
# Usage: scripts/set-grafana-github-credentials.sh

# shellcheck source=scripts/lib/grafana-datasource.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/grafana-datasource.sh"

PROJECT_ID="${PROJECT_ID:-alunduil}"
KEY_SECRET="${KEY_SECRET:-grafana-github-app-private-key}"
DATASOURCE_UID="${DATASOURCE_UID:-github}"

private_key="$(gcloud secrets versions access latest --secret="${KEY_SECRET}" --project="${PROJECT_ID}")"
set_datasource_private_key "${DATASOURCE_UID}" "${private_key}"
