#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Idempotently configures the eight GitHub Actions secrets that the Terraform
# CI workflows consume. Four values come from `terraform output` against
# terraform/bootstrap/; four come from externally-minted tokens supplied via
# environment variables (or prompted for interactively if unset).
#
# Re-running is a no-op modulo prompts: `gh secret set` upserts.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="${REPO_ROOT}/terraform/bootstrap"

command -v gh >/dev/null || { echo "error: gh CLI not found in PATH"; exit 1; }
command -v terraform >/dev/null || { echo "error: terraform CLI not found in PATH"; exit 1; }

gh auth status >/dev/null 2>&1 || { echo "error: gh is not authenticated; run 'gh auth login'"; exit 1; }

# Pull derived values from bootstrap state. Fails loudly if bootstrap hasn't
# been applied yet — there's no useful fallback.
WIF_PROVIDER="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw workload_identity_provider)"
RO_SA_EMAIL="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw github_deployer_ro_email)"
RW_SA_EMAIL="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw github_deployer_rw_email)"

# Prompt for any externally-minted token not already in the environment.
# `read -s` keeps the value off the terminal and never touches disk.
prompt_if_unset() {
  local var="$1"
  if [[ -z "${!var:-}" ]]; then
    read -r -s -p "Enter value for ${var}: " value
    echo
    printf -v "${var}" '%s' "${value}"
    export "${var?}"
  fi
}

prompt_if_unset TF_VAR_CLOUDFLARE_API_TOKEN_RO
prompt_if_unset TF_VAR_CLOUDFLARE_API_TOKEN_RW
prompt_if_unset GH_PROVIDER_TOKEN_RO
prompt_if_unset GH_PROVIDER_TOKEN_RW

# Same WIF provider value is mapped to both RO and RW secret names for
# symmetry with the workflow consumers (see #63).
declare -A SECRETS=(
  [GCP_RO_WORKLOAD_IDENTITY_PROVIDER]="${WIF_PROVIDER}"
  [GCP_RO_SERVICE_ACCOUNT_EMAIL]="${RO_SA_EMAIL}"
  [GCP_RW_WORKLOAD_IDENTITY_PROVIDER]="${WIF_PROVIDER}"
  [GCP_RW_SERVICE_ACCOUNT_EMAIL]="${RW_SA_EMAIL}"
  [TF_VAR_CLOUDFLARE_API_TOKEN_RO]="${TF_VAR_CLOUDFLARE_API_TOKEN_RO}"
  [TF_VAR_CLOUDFLARE_API_TOKEN_RW]="${TF_VAR_CLOUDFLARE_API_TOKEN_RW}"
  [GH_PROVIDER_TOKEN_RO]="${GH_PROVIDER_TOKEN_RO}"
  [GH_PROVIDER_TOKEN_RW]="${GH_PROVIDER_TOKEN_RW}"
)

for name in "${!SECRETS[@]}"; do
  echo "Setting secret: ${name}"
  gh secret set "${name}" --body "${SECRETS[${name}]}"
done

echo
echo "== Drift check =="
expected=$(printf '%s\n' "${!SECRETS[@]}" | sort)
actual=$(gh secret list --json name --jq '.[].name' | sort)

unexpected=$(comm -23 <(echo "${actual}") <(echo "${expected}") || true)
missing=$(comm -13 <(echo "${actual}") <(echo "${expected}") || true)

if [[ -n "${unexpected}" ]]; then
  echo "warn: unexpected secrets in repo (not managed by this script):"
  echo "${unexpected}" | sed 's/^/  - /'
fi

if [[ -n "${missing}" ]]; then
  echo "error: missing secrets (should have been set above — this is a bug):"
  echo "${missing}" | sed 's/^/  - /'
  exit 1
fi

if [[ -z "${unexpected}" && -z "${missing}" ]]; then
  echo "All eight secrets present, no drift."
fi
