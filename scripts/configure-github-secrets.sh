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
# Two come from a GitHub App (GH_APP_ID, GH_APP_PRIVATE_KEY) which the
# workflow exchanges for short-lived installation tokens via OIDC. For each:
#   1. use env var if set
#   2. else keep existing secret value if already present
#   3. else print mint instructions and prompt via `read -s`
#
# Re-running is a no-op: `gh secret set` upserts.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="${REPO_ROOT}/terraform/bootstrap"

command -v gh >/dev/null || { echo "error: gh CLI not found in PATH" >&2; exit 1; }
command -v terraform >/dev/null || { echo "error: terraform CLI not found in PATH" >&2; exit 1; }

gh auth status >/dev/null 2>&1 || { echo "error: gh is not authenticated; run 'gh auth login'" >&2; exit 1; }

WIF_PROVIDER="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw workload_identity_provider)"
RO_SA_EMAIL="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw github_deployer_ro_email)"
RW_SA_EMAIL="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw github_deployer_rw_email)"
CF_TOKEN_RO="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw cloudflare_api_token_deployer_ro)"
CF_TOKEN_RW="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw cloudflare_api_token_deployer_rw)"

# Snapshot current secret names so we can tell which GH App values are
# already populated and which need a prompt.
existing_secrets="$(gh secret list --json name --jq '.[].name')"
has_secret() { grep -Fxq "$1" <<<"${existing_secrets}"; }

print_gh_app_instructions() {
  cat >&2 <<'EOF'

The GitHub App authenticates the terraform github provider for cross-repo
management without a long-lived PAT. One-time setup:

  1. https://github.com/settings/apps/new
  2. Name: alunduil-infrastructure-deployer (or similar)
  3. Webhook: uncheck "Active"
  4. Repository permissions:
       Administration: Read and write
       Contents:       Read and write
       Metadata:       Read (auto)
       Pages:          Read and write
  5. Install on: your account, "All repositories"
  6. After create: copy the App ID; generate and download a private key
     (.pem). The values below should be the App ID and the contents of
     the .pem file.

EOF
}

# For each GH App secret: env wins; existing secret wins next; else prompt.
# Print mint instructions once upfront if either will need a prompt — running
# the prompts inside command substitution would lose any state set in the
# subshell.
needs_prompt() {
  local var="$1"
  [[ -z "${!var:-}" ]] && ! has_secret "${var}"
}

if needs_prompt GH_APP_ID || needs_prompt GH_APP_PRIVATE_KEY; then
  print_gh_app_instructions
fi

# GH_APP_PRIVATE_KEY is a multi-line PEM; trying to prompt for it via `read`
# is fiddly and burns the terminal scrollback. Fail with instructions instead
# so the operator pipes the .pem into the env var and re-runs.
if needs_prompt GH_APP_PRIVATE_KEY; then
  cat >&2 <<'EOF'
error: GH_APP_PRIVATE_KEY not in env and not in repo secrets.

Source it from the downloaded .pem file, then re-run this script:

  export GH_APP_PRIVATE_KEY="$(cat /path/to/your-app.pem)"

EOF
  exit 1
fi

resolve_gh_app_secret() {
  local var="$1" prompt_label="$2"
  if [[ -n "${!var:-}" ]]; then
    printf '%s' "${!var}"
  elif has_secret "${var}"; then
    echo "${var} already set in repo secrets; leaving as-is" >&2
    printf '__KEEP__'
  else
    local value
    read -r -s -p "Enter ${prompt_label}: " value >&2
    echo >&2
    printf '%s' "${value}"
  fi
}

GH_APP_ID_VALUE="$(resolve_gh_app_secret GH_APP_ID 'GH_APP_ID (numeric)')"
GH_APP_PRIVATE_KEY_VALUE="$(resolve_gh_app_secret GH_APP_PRIVATE_KEY GH_APP_PRIVATE_KEY)"

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
  echo "${unexpected}" | sed 's/^/  - /'
fi

if [[ -n "${missing}" ]]; then
  echo "error: missing secrets (should have been set above — this is a bug):" >&2
  echo "${missing}" | sed 's/^/  - /' >&2
  exit 1
fi

if [[ -z "${unexpected}" && -z "${missing}" ]]; then
  echo "All eight secrets present, no drift."
fi
