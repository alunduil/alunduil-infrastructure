#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Idempotently configures the eight GitHub Actions secrets that the Terraform
# CI workflows consume.
#
# Six values come from `terraform output` against terraform/bootstrap/:
#   - GCP_RO_WORKLOAD_IDENTITY_PROVIDER, GCP_RO_SERVICE_ACCOUNT_EMAIL
#   - GCP_RW_WORKLOAD_IDENTITY_PROVIDER, GCP_RW_SERVICE_ACCOUNT_EMAIL
#   - TF_VAR_CLOUDFLARE_API_TOKEN_RO, TF_VAR_CLOUDFLARE_API_TOKEN_RW
#
# Two come from a GitHub App that the workflow exchanges for short-lived
# installation tokens via OIDC:
#   - GH_APP_ID                — env var GH_APP_ID, existing secret, or prompt
#   - GH_APP_PRIVATE_KEY       — read from a .pem file path supplied via
#                                env var GH_APP_PRIVATE_KEY_FILE, existing
#                                secret, or prompt for the path
#
# Re-running is a no-op: `gh secret set` upserts.

set -euo pipefail

command -v gh >/dev/null || {
  echo "error: gh CLI not found in PATH" >&2
  exit 1
}
command -v git >/dev/null || {
  echo "error: git CLI not found in PATH" >&2
  exit 1
}
command -v terraform >/dev/null || {
  echo "error: terraform CLI not found in PATH" >&2
  exit 1
}

REPO_ROOT="$(git rev-parse --show-toplevel)" || {
  echo "error: not inside a git work tree" >&2
  exit 1
}
BOOTSTRAP_DIR="${REPO_ROOT}/terraform/bootstrap"

gh auth status >/dev/null 2>&1 || {
  echo "error: gh is not authenticated; run 'gh auth login'" >&2
  exit 1
}

WIF_PROVIDER="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw workload_identity_provider)"
RO_SA_EMAIL="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw github_deployer_ro_email)"
RW_SA_EMAIL="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw github_deployer_rw_email)"
CF_TOKEN_RO="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw cloudflare_api_token_deployer_ro)"
CF_TOKEN_RW="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw cloudflare_api_token_deployer_rw)"

existing_secrets="$(gh secret list --json name --jq '.[].name')"
has_secret() { grep -Fxq "$1" <<<"${existing_secrets}"; }

# Print App-creation pointer once upfront if either GH App value needs a
# prompt — running the prompts inside command substitution would lose any
# state set in the subshell.
print_gh_app_pointer() {
  cat >&2 <<'EOF'

The GitHub App authenticates the terraform github provider in CI. If
you haven't created one yet, see docs/how-to/create-github-app.md.

EOF
}

needs_id_prompt() {
  [[ -z "${GH_APP_ID:-}" ]] && ! has_secret "GH_APP_ID"
}

needs_key_prompt() {
  [[ -z "${GH_APP_PRIVATE_KEY_FILE:-}" ]] && ! has_secret "GH_APP_PRIVATE_KEY"
}

if needs_id_prompt || needs_key_prompt; then
  print_gh_app_pointer
fi

resolve_gh_app_id() {
  if [[ -n "${GH_APP_ID:-}" ]]; then
    printf '%s' "${GH_APP_ID}"
  elif has_secret "GH_APP_ID"; then # pragma: allowlist secret
    echo "GH_APP_ID already set in repo secrets; leaving as-is" >&2
    printf '__KEEP__'
  else
    local value
    read -r -p "Enter GH_APP_ID (numeric, visible on App settings page): " value
    printf '%s' "${value}"
  fi
}

resolve_gh_app_private_key() {
  local path
  if [[ -n "${GH_APP_PRIVATE_KEY_FILE:-}" ]]; then
    path="${GH_APP_PRIVATE_KEY_FILE}"
  elif has_secret "GH_APP_PRIVATE_KEY"; then # pragma: allowlist secret
    echo "GH_APP_PRIVATE_KEY already set in repo secrets; leaving as-is" >&2
    printf '__KEEP__'
    return
  else
    read -r -p "Path to GitHub App private key (.pem): " path
  fi
  path="${path/#\~/${HOME}}"
  [[ -r "${path}" ]] || {
    echo "error: cannot read '${path}'" >&2
    exit 1
  }
  cat "${path}"
}

GH_APP_ID_VALUE="$(resolve_gh_app_id)"
GH_APP_PRIVATE_KEY_VALUE="$(resolve_gh_app_private_key)"

# Same WIF provider value maps to both RO and RW secret names for symmetry
# with the workflow consumers (see #63).
declare -A SECRETS=(
  [GCP_RO_WORKLOAD_IDENTITY_PROVIDER]="${WIF_PROVIDER}"
  [GCP_RO_SERVICE_ACCOUNT_EMAIL]="${RO_SA_EMAIL}"
  [GCP_RW_WORKLOAD_IDENTITY_PROVIDER]="${WIF_PROVIDER}"
  [GCP_RW_SERVICE_ACCOUNT_EMAIL]="${RW_SA_EMAIL}"
  [TF_VAR_CLOUDFLARE_API_TOKEN_RO]="${CF_TOKEN_RO}"
  [TF_VAR_CLOUDFLARE_API_TOKEN_RW]="${CF_TOKEN_RW}"
  [GH_APP_ID]="${GH_APP_ID_VALUE}"
  [GH_APP_PRIVATE_KEY]="${GH_APP_PRIVATE_KEY_VALUE}"
)

for name in "${!SECRETS[@]}"; do
  if [[ "${SECRETS[${name}]}" == "__KEEP__" ]]; then
    continue
  fi
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
  # shellcheck disable=SC2001 # leading "  - " bullet — readable as sed
  echo "${unexpected}" | sed 's/^/  - /'
fi

if [[ -n "${missing}" ]]; then
  echo "error: missing secrets (should have been set above — this is a bug):" >&2
  # shellcheck disable=SC2001 # leading "  - " bullet — readable as sed
  echo "${missing}" | sed 's/^/  - /' >&2
  exit 1
fi

if [[ -z "${unexpected}" && -z "${missing}" ]]; then
  echo "All eight secrets present, no drift."
fi
