#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Writes the hook-fix GitHub App's ID and private key as Actions secrets to
# every repo with a renovate ruleset. Re-running writes only what a repo lacks.

set -euo pipefail

SETUP_DOC="docs/how-to/create-hook-fix-github-app.md"

die() {
  echo "error: $*" >&2
  exit 1
}

print_app_pointer() {
  cat >&2 <<EOF

The next values belong to the GitHub App named alunduil-hook-fix. If it does
not exist yet, see ${SETUP_DOC}.

EOF
}

# A supplied value overwrites, which is how a rotated key reaches every repo.
needs_write() {
  local name="$1" supplied="$2" repo_secrets="$3"
  [[ -n ${supplied} ]] || ! grep -Fxq "${name}" <<<"${repo_secrets}"
}

resolve_app_id() {
  local value="${HOOK_FIX_APP_ID:-}"
  [[ -n ${value} ]] || read -r -p "alunduil-hook-fix App ID (Enter to skip): " value
  [[ -n ${value} ]] || return 0

  # An ID from another App passes every check here and only surfaces when the
  # first fix push is refused, so reject what can't be an ID while it's in hand.
  [[ ${value} =~ ^[0-9]+$ ]] || die "App ID must be digits, got '${value}'"
  printf '%s' "${value}"
}

resolve_app_private_key() {
  local path="${HOOK_FIX_APP_PRIVATE_KEY_FILE:-}"
  [[ -n ${path} ]] || read -r -p "Path to the alunduil-hook-fix private key .pem (Enter to skip): " path
  [[ -n ${path} ]] || return 0

  # read hands back the tilde the shell would have expanded.
  path="${path/#\~/${HOME}}"

  [[ -r ${path} ]] || die "cannot read '${path}'"
  grep -q -- '-----BEGIN .*PRIVATE KEY-----' "${path}" \
    || die "'${path}' is not a PEM private key"
  cat "${path}"
}

# The operator answers each prompt at most once, and never for a value no repo
# receives.
set_secret_on_repos() {
  local name="$1" resolve="$2"
  shift 2
  (($#)) || return 0

  local value repo
  value="$("${resolve}")"
  [[ -n ${value} ]] || {
    echo "Leaving ${name} unset; see ${SETUP_DOC}" >&2
    return 0
  }

  for repo in "$@"; do
    echo "Setting secret: ${name} (repo: ${repo})"
    gh secret set "${name}" --repo "${repo}" --body "${value}"
  done
}

# The renovate ruleset grants the App its bypass, so only repos carrying it get
# the key. allow_auto_merge is also on in repos Terraform doesn't manage.
renovate_repos() {
  # shellcheck disable=SC2016 # $endCursor is a GraphQL variable, not a shell one
  gh api graphql --paginate -f query='
    query($endCursor: String) {
      viewer {
        repositories(ownerAffiliations: OWNER, isArchived: false, first: 100, after: $endCursor) {
          pageInfo { hasNextPage endCursor }
          nodes { nameWithOwner rulesets(first: 20) { nodes { name } } }
        }
      }
    }' --jq '.data.viewer.repositories.nodes[]
      | select(any(.rulesets.nodes[]; .name == "renovate"))
      | .nameWithOwner'
}

# Skip the executable body when sourced (e.g. by
# configure-hook-fix-secrets.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

command -v gh >/dev/null || die "gh CLI not found in PATH"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated; run 'gh auth login'"

mapfile -t repos < <(renovate_repos)
id_repos=()
key_repos=()
for repo in "${repos[@]}"; do
  repo_secrets="$(gh secret list --repo "${repo}" --json name --jq '.[].name')"
  if needs_write HOOK_FIX_APP_ID "${HOOK_FIX_APP_ID:-}" "${repo_secrets}"; then
    id_repos+=("${repo}")
  fi
  if needs_write HOOK_FIX_APP_PRIVATE_KEY "${HOOK_FIX_APP_PRIVATE_KEY_FILE:-}" "${repo_secrets}"; then
    key_repos+=("${repo}")
  fi
done

if [[ ${#id_repos[@]} -eq 0 && ${#key_repos[@]} -eq 0 ]]; then
  echo "Every repo with a renovate ruleset holds both secrets."
  exit 0
fi

if [[ ${#id_repos[@]} -gt 0 && -z "${HOOK_FIX_APP_ID:-}" ]] \
  || [[ ${#key_repos[@]} -gt 0 && -z "${HOOK_FIX_APP_PRIVATE_KEY_FILE:-}" ]]; then
  print_app_pointer
fi

set_secret_on_repos HOOK_FIX_APP_ID resolve_app_id "${id_repos[@]}"
set_secret_on_repos HOOK_FIX_APP_PRIVATE_KEY resolve_app_private_key "${key_repos[@]}"
