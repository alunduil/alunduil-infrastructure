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
  local role="$1" id="$2" key_file="$3"
  # shellcheck disable=SC2034 # read by lib/app-secrets.sh
  local APP_NAME="$4" pointer_shown=""

  ensure_secret "terraform-github-app-id-${role}" "${APP_NAME} App ID" \
    "${id}" check_digits
  ensure_secret "terraform-github-app-private-key-${role}" \
    "Path to the ${APP_NAME} private key .pem" "${key_file}" read_private_key
}

configure_app ro "${TERRAFORM_GITHUB_APP_ID_RO:-}" \
  "${TERRAFORM_GITHUB_APP_PRIVATE_KEY_FILE_RO:-}" alunduil-terraform-plan
configure_app rw "${TERRAFORM_GITHUB_APP_ID_RW:-}" \
  "${TERRAFORM_GITHUB_APP_PRIVATE_KEY_FILE_RW:-}" alunduil-terraform-apply
