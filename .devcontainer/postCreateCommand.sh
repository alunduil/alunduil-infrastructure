#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

set -euo pipefail
set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# ---------------------------------------------------------------------------
# 1. Google Cloud SDK
# ---------------------------------------------------------------------------
step "Installing Google Cloud SDK"

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list && \
sudo apt-get update && sudo apt-get install -y google-cloud-sdk

# ---------------------------------------------------------------------------
# 2. Pre-commit hooks
# ---------------------------------------------------------------------------
step "Installing pre-commit hooks"

pre-commit install

# ---------------------------------------------------------------------------
# 3. SPDX license compliance checker
# ---------------------------------------------------------------------------
step "Installing reuse-tool"

pipx install reuse==6.2.0

# ---------------------------------------------------------------------------
# Verify and report
# ---------------------------------------------------------------------------

run_verification
run_version_summary
run_status
