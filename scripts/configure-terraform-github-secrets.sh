#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the Terraform GitHub Apps' IDs and private keys in the Secret Manager
# shells terraform/bootstrap/terraform_github_app.tf declares.

set -euo pipefail

# shellcheck disable=SC2034 # read by lib/app-secrets.sh
SETUP_DOC="docs/how-to/create-terraform-github-apps.md"

# shellcheck source=scripts/lib/app-secrets.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/app-secrets.sh"

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

# The Apps differ only by permissions, and swapping their answers hands plan
# the write key, so every prompt names its App.
#
# The locals shadow lib/app-secrets.sh's globals, giving each App its own name
# and pointer.
configure_app() {
  # shellcheck disable=SC2034 # APP_NAME and pointer_shown are read by lib/app-secrets.sh
  local role="$1" APP_NAME="$2" id="$3" key_file="$4" pointer_shown=""

  ensure_secret "terraform-github-app-id-${role}" "${APP_NAME} App ID" \
    "${id}" check_digits
  ensure_secret "terraform-github-app-private-key-${role}" \
    "Path to the ${APP_NAME} private key .pem" "${key_file}" read_private_key
}

configure_app ro alunduil-terraform-plan \
  "${TERRAFORM_PLAN_APP_ID:-}" "${TERRAFORM_PLAN_APP_PRIVATE_KEY_FILE:-}"
configure_app rw alunduil-terraform-apply \
  "${TERRAFORM_APPLY_APP_ID:-}" "${TERRAFORM_APPLY_APP_PRIVATE_KEY_FILE:-}"
