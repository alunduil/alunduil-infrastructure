#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Configures the GitHub Actions secrets the CI workflows consume, here, in
# blog.alunduil.com, and in release-gate. Re-running is a no-op.

set -euo pipefail

# The Projects sync token is scoped to this deployment environment
# (restricted to main) so only the sync workflow, which declares the
# environment, can read it. Every other secret stays repo-level.
ENVIRONMENT="project-sync"

# blog.alunduil.com's Pages build federates into this project to read its
# Cloudflare analytics token, so its identifiers are configured here too.
BLOG_REPO="alunduil/blog.alunduil.com"

# release-gate's deploy workflow federates in the same way, to read the gate's
# App key, webhook secret, and Worker deploy token.
RELEASE_GATE_REPO="alunduil/release-gate"

# existing_env_secrets is populated by the executable body (from
# `gh secret list`) before these run; the bats suite sets it directly.
has_env_secret() { grep -Fxq "$1" <<<"${existing_env_secrets}"; }

# A value is prompted for only when it is neither supplied via the
# environment nor already present as a secret — so a re-run never clobbers
# an existing secret with a fresh prompt.
needs_token_prompt() {
  [[ -z "${GH_PROJECT_SYNC_TOKEN:-}" ]] && ! has_env_secret "GH_PROJECT_SYNC_TOKEN"
}

print_project_sync_token_pointer() {
  cat >&2 <<'EOF'

GH_PROJECT_SYNC_TOKEN authenticates the hourly Projects sync workflow.
If you haven't created one yet, see
docs/how-to/create-github-project-sync-token.md.

EOF
}

# Precedence: an explicit environment value wins; otherwise an already-set
# secret is left untouched (signalled by the __KEEP__ sentinel); otherwise
# prompt.
resolve_project_sync_token() {
  if [[ -n "${GH_PROJECT_SYNC_TOKEN:-}" ]]; then
    printf '%s' "${GH_PROJECT_SYNC_TOKEN}"
  elif has_env_secret "GH_PROJECT_SYNC_TOKEN"; then # pragma: allowlist secret
    echo "GH_PROJECT_SYNC_TOKEN already set in the ${ENVIRONMENT} environment; leaving as-is" >&2
    printf '__KEEP__'
  else
    local value
    read -r -s -p "Paste GH_PROJECT_SYNC_TOKEN (input hidden, then press Enter): " value
    echo >&2
    printf '%s' "${value}"
  fi
}

# token_scopes <token>: print a classic token's scopes, as GitHub reports
# them in X-OAuth-Scopes, sorted and comma-joined.
token_scopes() {
  GH_TOKEN="$1" gh api --include user \
    | grep -i '^x-oauth-scopes:' | cut -d: -f2- | tr -d ' \r' \
    | tr ',' '\n' | grep -v '^$' | sort | paste -sd, -
}

# check_project_sync_token <token>: fail unless the token holds exactly
# `project` and `read:org`. `repo` or `public_repo` would let it write to
# every repository the account can.
check_project_sync_token() {
  local scopes
  scopes="$(token_scopes "$1")"
  if [[ ${scopes} != "project,read:org" ]]; then
    echo "error: GH_PROJECT_SYNC_TOKEN has scopes '${scopes}', not exactly project and read:org;" \
      "see docs/how-to/create-github-project-sync-token.md" >&2
    return 1
  fi
}

tf_output() {
  terraform -chdir="${BOOTSTRAP_DIR}" output -raw "$1"
}

set_secret() {
  local name="$1" value="$2" repo="${3:-}"
  local target=() label=""

  if [[ -n ${repo} ]]; then
    target=(--repo "${repo}")
    label=" (repo: ${repo})"
  fi

  echo "Setting secret: ${name}${label}"
  gh secret set "${name}" "${target[@]}" --body "${value}"
}

# Sets each NAME VALUE pair that follows the repo.
set_secrets() {
  local repo="$1"
  shift

  while (($# >= 2)); do
    set_secret "$1" "$2" "${repo}"
    shift 2
  done
}

ensure_environment() {
  gh api -X PUT "repos/{owner}/{repo}/environments/${ENVIRONMENT}" \
    --input - >/dev/null <<'JSON'
{
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
JSON
  local policies
  policies="$(gh api "repos/{owner}/{repo}/environments/${ENVIRONMENT}/deployment-branch-policies" \
    --jq '.branch_policies[].name' 2>/dev/null || true)"
  if ! grep -Fxq "main" <<<"${policies}"; then
    gh api -X POST "repos/{owner}/{repo}/environments/${ENVIRONMENT}/deployment-branch-policies" \
      -f "name=main" >/dev/null
  fi
}

# Skip the executable body when sourced (e.g. by configure-github-secrets.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

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

WIF_PROVIDER="$(tf_output workload_identity_provider)"
RO_SA_EMAIL="$(tf_output github_deployer_ro_email)"
RW_SA_EMAIL="$(tf_output github_deployer_rw_email)"
BLOG_WIF_PROVIDER="$(tf_output blog_analytics_workload_identity_provider)"
BLOG_SA_EMAIL="$(tf_output blog_analytics_reader_email)"
BLOG_SECRET_MANAGER_ID="$(tf_output cloudflare_api_token_blog_analytics_ro_secret)"
RELEASE_GATE_WIF_PROVIDER="$(tf_output release_gate_workload_identity_provider)"
RELEASE_GATE_SA_EMAIL="$(tf_output release_gate_reader_email)"
RELEASE_GATE_APP_KEY_ID="$(tf_output release_gate_app_private_key_secret)"
RELEASE_GATE_WEBHOOK_ID="$(tf_output release_gate_webhook_secret_secret)"
RELEASE_GATE_DEPLOY_TOKEN_ID="$(tf_output cloudflare_api_token_release_gate_deploy_secret)"

existing_env_secrets="$(gh secret list --env "${ENVIRONMENT}" --json name --jq '.[].name' 2>/dev/null || true)"

if needs_token_prompt; then
  print_project_sync_token_pointer
fi

GH_PROJECT_SYNC_TOKEN_VALUE="$(resolve_project_sync_token)"
if [[ "${GH_PROJECT_SYNC_TOKEN_VALUE}" != "__KEEP__" ]]; then
  check_project_sync_token "${GH_PROJECT_SYNC_TOKEN_VALUE}" || exit 1
fi

declare -A SECRETS=(
  [GCP_RO_WORKLOAD_IDENTITY_PROVIDER]="${WIF_PROVIDER}"
  [GCP_RO_SERVICE_ACCOUNT_EMAIL]="${RO_SA_EMAIL}"
  [GCP_RW_WORKLOAD_IDENTITY_PROVIDER]="${WIF_PROVIDER}"
  [GCP_RW_SERVICE_ACCOUNT_EMAIL]="${RW_SA_EMAIL}"
)

for name in "${!SECRETS[@]}"; do
  set_secret "${name}" "${SECRETS[${name}]}"
done

# Derived from terraform outputs, so a pool or service account recreated here
# reaches the other repos on the next run. A stale value fails the token
# exchange, which the blog's build doesn't surface. The drift check below stays
# scoped to this repo: these are the only names we own there.
set_secrets "${BLOG_REPO}" \
  GCP_WORKLOAD_IDENTITY_PROVIDER "${BLOG_WIF_PROVIDER}" \
  GCP_SERVICE_ACCOUNT_EMAIL "${BLOG_SA_EMAIL}" \
  CLOUDFLARE_ANALYTICS_SECRET_NAME "${BLOG_SECRET_MANAGER_ID}"

set_secrets "${RELEASE_GATE_REPO}" \
  GCP_WORKLOAD_IDENTITY_PROVIDER "${RELEASE_GATE_WIF_PROVIDER}" \
  GCP_SERVICE_ACCOUNT_EMAIL "${RELEASE_GATE_SA_EMAIL}" \
  APP_PRIVATE_KEY_SECRET_NAME "${RELEASE_GATE_APP_KEY_ID}" \
  WEBHOOK_SECRET_SECRET_NAME "${RELEASE_GATE_WEBHOOK_ID}" \
  CLOUDFLARE_API_TOKEN_SECRET_NAME "${RELEASE_GATE_DEPLOY_TOKEN_ID}"

ensure_environment
if [[ "${GH_PROJECT_SYNC_TOKEN_VALUE}" != "__KEEP__" ]]; then
  echo "Setting secret: GH_PROJECT_SYNC_TOKEN (environment: ${ENVIRONMENT})"
  gh secret set GH_PROJECT_SYNC_TOKEN --env "${ENVIRONMENT}" \
    --body "${GH_PROJECT_SYNC_TOKEN_VALUE}"
fi

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
  echo "No drift."
fi
