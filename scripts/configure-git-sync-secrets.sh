#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the Git Sync GitHub App credentials in the Secret Manager shells
# terraform/bootstrap/ declares. Each value is written once, so re-running is a
# no-op and the bootstrap layer stays editable without the .pem GitHub shows
# once. Replacing a value goes through docs/how-to/rotate-git-sync-app-key.md.

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-alunduil}"
SETUP_DOC="docs/how-to/create-git-sync-github-app.md"

die() {
  echo "error: $*" >&2
  exit 1
}

# Every check reaches Secret Manager. A stale answer here would report a
# populated secret as empty, and the next answer would overwrite it.
secret_is_populated() {
  local state
  state="$(gcloud secrets versions describe latest --secret "${1}" \
    --project "${PROJECT_ID}" --format='value(state)' 2>/dev/null || true)"

  [[ ${state} == "ENABLED" ]]
}

add_secret_version() {
  gcloud secrets versions add "${1}" --project "${PROJECT_ID}" --data-file=-
}

# True when answer_for would put a question to the operator.
will_prompt() { [[ -z ${1} && -t 0 ]]; }

pointer_shown=""

# The ensure_* functions run in this shell, so the flag survives between them.
# Moving this inside answer_for would lose it: that result comes back through a
# command substitution, and the subshell would discard the flag, repeating the
# pointer at every question.
announce_app_once() {
  [[ -z ${pointer_shown} ]] || return 0

  pointer_shown=yes
  print_git_sync_app_pointer
}

# Several Apps on the account have names that read like this one, and an App ID
# from the wrong one passes every check here — it is digits, and Secret Manager
# takes it. The mismatch only surfaces as an opaque Grafana authentication
# failure a long way from the prompt. The name below can be edited in the UI;
# the installation scope is what stays true.
print_git_sync_app_pointer() {
  cat >&2 <<EOF

The next values belong to the GitHub App named Grafana Cloud GitHub Sync,
installed on alunduil-infrastructure alone. Settings > Applications > Installed
GitHub Apps lists every installation, and Configure puts that installation's ID
in the address bar.

If the App does not exist yet, press Enter past each prompt and see
${SETUP_DOC}.

EOF
}

# Succeeds, and says so, when the secret already holds a value.
already_stored() {
  secret_is_populated "${1}" || return 1

  echo "${1} already set."
}

skip_notice() {
  echo "Leaving ${1} empty; see ${SETUP_DOC}" >&2
}

# Precedence: the supplied value, else what the operator types, else nothing.
# read prompts on stderr, so only the answer reaches stdout.
answer_for() {
  local prompt="${1}" value="${2}"

  if will_prompt "${value}"; then
    read -r -p "${prompt} (Enter to skip): " value
  fi

  printf '%s' "${value}"
}

ensure_identifier() {
  local secret="${1}" prompt="${2}" value="${3}"

  already_stored "${secret}" && return
  will_prompt "${value}" && announce_app_once
  value="$(answer_for "${prompt}" "${value}")"
  [[ -n ${value} ]] || {
    skip_notice "${secret}"
    return
  }

  [[ ${value} =~ ^[0-9]+$ ]] || die "${prompt} must be digits, got '${value}'"

  # No trailing newline: consumers read the value straight into a TF_VAR, where
  # a stray byte would reach the Grafana connection resource.
  printf '%s' "${value}" | add_secret_version "${secret}"
}

ensure_private_key() {
  local secret="${1}" prompt="${2}" path="${3}"

  already_stored "${secret}" && return
  will_prompt "${path}" && announce_app_once
  path="$(answer_for "${prompt}" "${path}")"
  [[ -n ${path} ]] || {
    skip_notice "${secret}"
    return
  }

  # read hands back the tilde the shell would have expanded.
  path="${path/#\~/${HOME}}"

  [[ -r ${path} ]] || die "cannot read '${path}'"

  # Wrong bytes fail inside Grafana, far from here, so check the header while
  # the file is still in hand.
  grep -q -- '-----BEGIN .*PRIVATE KEY-----' "${path}" \
    || die "'${path}' is not a PEM private key"

  add_secret_version "${secret}" <"${path}"
  echo "Shred ${path} once terraform/alunduil/ has applied."
}

# Skip the executable body when sourced (e.g. by
# configure-git-sync-secrets.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

# Registering the App yields its ID and private key; installing it on the repo
# yields the installation ID. Both are browser actions, so a run before either
# legitimately leaves secrets empty.
ensure_identifier grafana-git-sync-app-id \
  "Grafana Cloud GitHub Sync App ID" "${GIT_SYNC_APP_ID:-}"
ensure_identifier grafana-git-sync-app-installation-id \
  "Grafana Cloud GitHub Sync installation ID" "${GIT_SYNC_APP_INSTALLATION_ID:-}"
ensure_private_key grafana-git-sync-app-private-key \
  "Path to the Grafana Cloud GitHub Sync private key .pem" "${GIT_SYNC_APP_PRIVATE_KEY_FILE:-}"
