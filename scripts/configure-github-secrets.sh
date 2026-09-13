#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Configures the GitHub Actions secrets the CI workflows consume, here and
# in blog.alunduil.com. Re-running is a no-op.

set -euo pipefail

# The Projects sync token is scoped to this deployment environment
# (restricted to main) so only the sync workflow, which declares the
# environment, can read it. Every other secret stays repo-level.
ENVIRONMENT="project-sync"

# blog.alunduil.com's Pages build federates into this project to read its
# Cloudflare analytics token, so its identifiers are configured here too.
BLOG_REPO="alunduil/blog.alunduil.com"

# existing_secrets / existing_env_secrets are populated by the executable
# body (from `gh secret list`) before these run; the bats suite sets them
# directly.
has_secret() { grep -Fxq "$1" <<<"${existing_secrets}"; }
has_env_secret() { grep -Fxq "$1" <<<"${existing_env_secrets}"; }

print_gh_app_pointer() {
  cat >&2 <<'EOF'

The GitHub App authenticates the terraform github provider in CI. If
you haven't created one yet, see docs/how-to/create-deployer-github-app.md.

EOF
}

# A value is prompted for only when it is neither supplied via the
# environment nor already present as a secret — so a re-run never clobbers
# an existing secret with a fresh prompt.
needs_id_prompt() {
  [[ -z "${GH_APP_ID:-}" ]] && ! has_secret "GH_APP_ID"
}

needs_key_prompt() {
  [[ -z "${GH_APP_PRIVATE_KEY_FILE:-}" ]] && ! has_secret "GH_APP_PRIVATE_KEY"
}

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

# The resolve_* helpers follow one precedence: an explicit environment
# value wins; otherwise an already-set secret is left untouched (signalled
# by the __KEEP__ sentinel, which the setters below skip); otherwise prompt.
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

# BOOTSTRAP_DIR is populated by the executable body, as the *_secrets
# globals above are.
tf_output() {
  terraform -chdir="${BOOTSTRAP_DIR}" output -raw "$1"
}

# Writes one secret, unless the resolved value is the __KEEP__ sentinel — which
# means it was already set and deliberately not re-resolved. Derived values
# never carry the sentinel, so they write on every run. A repo argument targets
# that repo instead of the current one.
set_secret() {
  local name="$1" value="$2" repo="${3:-}"
  local target=() label=""

  if [[ ${value} == "__KEEP__" ]]; then
    return
  fi

  if [[ -n ${repo} ]]; then
    target=(--repo "${repo}")
    label=" (repo: ${repo})"
  fi

  echo "Setting secret: ${name}${label}"
  gh secret set "${name}" "${target[@]}" --body "${value}"
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
BLOG_SECRET_NAME="$(tf_output cloudflare_api_token_blog_analytics_ro_secret)"

existing_secrets="$(gh secret list --json name --jq '.[].name')"
existing_env_secrets="$(gh secret list --env "${ENVIRONMENT}" --json name --jq '.[].name' 2>/dev/null || true)"

if needs_id_prompt || needs_key_prompt; then
  print_gh_app_pointer
fi

if needs_token_prompt; then
  print_project_sync_token_pointer
fi

GH_APP_ID_VALUE="$(resolve_gh_app_id)"
GH_APP_PRIVATE_KEY_VALUE="$(resolve_gh_app_private_key)"
GH_PROJECT_SYNC_TOKEN_VALUE="$(resolve_project_sync_token)"

declare -A SECRETS=(
  [GCP_RO_WORKLOAD_IDENTITY_PROVIDER]="${WIF_PROVIDER}"
  [GCP_RO_SERVICE_ACCOUNT_EMAIL]="${RO_SA_EMAIL}"
  [GCP_RW_WORKLOAD_IDENTITY_PROVIDER]="${WIF_PROVIDER}"
  [GCP_RW_SERVICE_ACCOUNT_EMAIL]="${RW_SA_EMAIL}"
  [GH_APP_ID]="${GH_APP_ID_VALUE}"
  [GH_APP_PRIVATE_KEY]="${GH_APP_PRIVATE_KEY_VALUE}"
)

for name in "${!SECRETS[@]}"; do
  set_secret "${name}" "${SECRETS[${name}]}"
done

declare -A BLOG_SECRETS=(
  [GCP_WORKLOAD_IDENTITY_PROVIDER]="${BLOG_WIF_PROVIDER}"
  [GCP_SERVICE_ACCOUNT_EMAIL]="${BLOG_SA_EMAIL}"
  [CLOUDFLARE_ANALYTICS_SECRET_NAME]="${BLOG_SECRET_NAME}"
)

# All three are derived from terraform outputs, so a pool or service account
# recreated here reaches the blog on the next run; a stale value there fails
# the token exchange without failing the build. The drift check below stays
# scoped to this repo: these names are the only ones we own in the blog's.
for name in "${!BLOG_SECRETS[@]}"; do
  set_secret "${name}" "${BLOG_SECRETS[${name}]}" "${BLOG_REPO}"
done

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
