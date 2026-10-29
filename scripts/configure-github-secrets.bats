#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the sourceable helpers in configure-github-secrets.sh: the
# needs_token_prompt precedence, the resolve_project_sync_token value/__KEEP__
# handling, and the command set_secret builds against a stubbed gh. The paths
# that reach the network or prompt (terraform, real gh, interactive read) are
# not exercised — they're covered by running the script against the live
# repo, which alunduil performs out-of-band.

# shellcheck disable=SC2034 # these globals are read by the sourced helpers
setup() {
  # Reset what the sourced helpers read, so each test starts clean.
  existing_env_secrets=""
  unset GH_PROJECT_SYNC_TOKEN
  # shellcheck source=configure-github-secrets.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/configure-github-secrets.sh"
}

# Lets a test assert the command that was built rather than reaching GitHub.
# set_secret calls it indirectly, which shellcheck can't follow.
# shellcheck disable=SC2329
gh() { echo "gh $*"; }

# --- needs_token_prompt ---------------------------------------------------

@test "needs_token_prompt keys on the environment-level secret list" {
  run needs_token_prompt
  [[ ${status} -eq 0 ]]
  existing_env_secrets=$'GH_PROJECT_SYNC_TOKEN'
  run needs_token_prompt
  [[ ${status} -eq 1 ]]
}

# --- resolve_project_sync_token -------------------------------------------

@test "resolve_project_sync_token returns the environment value when set" {
  GH_PROJECT_SYNC_TOKEN=ghp_example
  result="$(resolve_project_sync_token 2>/dev/null)"
  [[ ${result} == "ghp_example" ]]
}

@test "resolve_project_sync_token keeps an existing environment secret" {
  existing_env_secrets=$'GH_PROJECT_SYNC_TOKEN'
  result="$(resolve_project_sync_token 2>/dev/null)"
  [[ ${result} == "__KEEP__" ]]
}

# --- set_secret -----------------------------------------------------------

@test "set_secret writes a resolved value to the current repo" {
  run set_secret "GCP_RO_SERVICE_ACCOUNT_EMAIL" "sa@example.test"
  [[ ${output} == *"gh secret set GCP_RO_SERVICE_ACCOUNT_EMAIL --body sa@example.test"* ]]
  [[ ${output} != *"--repo"* ]]
}

@test "set_secret skips the __KEEP__ sentinel without calling gh" {
  run set_secret "GCP_RO_SERVICE_ACCOUNT_EMAIL" "__KEEP__"
  [[ ${output} != *"gh secret set"* ]]
}

@test "set_secret targets another repo when given one" {
  run set_secret "GCP_SERVICE_ACCOUNT_EMAIL" "sa@example.test" "owner/other"
  [[ ${output} == *"--repo owner/other"* ]]
  [[ ${output} == *"--body sa@example.test"* ]]
}

# Derived values never carry the sentinel, so nothing should skip them. This
# is the path that keeps a rotated identifier reaching the blog.
@test "set_secret writes a derived value through to another repo" {
  run set_secret "CLOUDFLARE_ANALYTICS_SECRET_NAME" "a-secret-name" "owner/other"
  [[ ${output} == *"gh secret set CLOUDFLARE_ANALYTICS_SECRET_NAME"* ]]
}
