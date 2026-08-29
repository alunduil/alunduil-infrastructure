#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Exports the provider credentials the Terraform workflows consume as TF_VAR_*
# entries in GITHUB_ENV. Takes the deployer role — ro for the plan workflow, rw
# for the apply — which selects the Cloudflare token version that deployer's SA
# holds secretAccessor on.

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-alunduil}"

access() {
  gcloud secrets versions access latest --secret="${1}" --project="${PROJECT_ID}"
}

# A workflow command occupies one line, so a multi-line value registers only
# when each of its lines is masked separately.
mask() {
  sed '/^$/d; s|^|::add-mask::|'
}

# Every value is masked before it reaches GITHUB_ENV: the runner echoes the env
# group of each following step, so an unmasked value lands in the log there.
# The heredoc form carries single- and multi-line values alike.
export_var() {
  local name="${1}" value="${2}"
  mask <<<"${value}"
  {
    echo "${name}<<__TFVAR__"
    echo "${value}"
    echo "__TFVAR__"
  } >>"${GITHUB_ENV}"
}

# Split from export_var so the masking and GITHUB_ENV contract stays testable
# without a gcloud on PATH. The separate assignment is load-bearing: a failing
# command substitution passed straight as an argument would export an empty
# value instead of tripping set -e.
export_secret() {
  local value
  value="$(access "${2}")"
  export_var "${1}" "${value}"
}

# Skip the executable body when sourced (e.g. by
# export-terraform-credentials.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

role="${1:-}"
case "${role}" in
  ro | rw) ;;
  *)
    echo "usage: ${0##*/} <ro|rw>" >&2
    exit 1
    ;;
esac

command -v gcloud >/dev/null || {
  echo "error: gcloud CLI not found in PATH" >&2
  exit 1
}

export_secret TF_VAR_cloudflare_api_token "cloudflare-api-token-deployer-${role}"

# Grafana provisioning has no read-only role, so plan and apply share one set of
# credentials. Every secret read here is populated by the bootstrap layer.
export_secret TF_VAR_grafana_service_account_token grafana-provisioner-token
export_secret TF_VAR_grafana_git_sync_app_private_key grafana-git-sync-app-private-key
