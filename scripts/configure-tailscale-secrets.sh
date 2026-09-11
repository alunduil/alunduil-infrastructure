#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the Tailscale OAuth client credentials in the Secret Manager shells
# terraform/bootstrap/ declares. Each value is written once, so re-running is a
# no-op and the bootstrap layer stays editable without the client secret the
# admin console shows once.

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-alunduil}"
SETUP_DOC="docs/how-to/create-tailscale-oauth-client.md"

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
announce_client_once() {
  [[ -z ${pointer_shown} ]] || return 0

  pointer_shown=yes
  print_oauth_client_pointer
}

# The ID and the secret are issued together and authenticate only as a pair.
# Mixing in a value from another client on the account passes every check here —
# both are opaque strings Secret Manager accepts — and surfaces much later as a
# provider authentication failure a long way from the prompt.
print_oauth_client_pointer() {
  cat >&2 <<EOF

The next two values belong to one OAuth client, listed under its description at
https://login.tailscale.com/admin/settings/oauth. The secret is shown only when
the client is generated, so a client whose secret was not captured then has to
be replaced rather than read.

If the client does not exist yet, press Enter past each prompt and see
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
# read prompts on stderr, so only the answer reaches stdout. hidden suppresses
# the echo for the client secret, whose prompt is the last place it appears in
# the clear.
answer_for() {
  local prompt="${1}" value="${2}" hidden="${3}"

  if will_prompt "${value}"; then
    read -r ${hidden:+-s} -p "${prompt} (Enter to skip): " value
    [[ -z ${hidden} ]] || echo >&2
  fi

  printf '%s' "${value}"
}

# Tailscale documents no format for either half, so the only check that can be
# made here is against a mangled paste: every credential the console issues is
# a single opaque token.
store_credential() {
  local secret="${1}" prompt="${2}" value="${3}" hidden="${4}"

  already_stored "${secret}" && return
  will_prompt "${value}" && announce_client_once
  value="$(answer_for "${prompt}" "${value}" "${hidden}")"
  [[ -n ${value} ]] || {
    skip_notice "${secret}"
    return
  }

  [[ ${value} != *[[:space:]]* ]] || die "${prompt} must not contain whitespace"

  # No trailing newline: consumers read the value straight into a TF_VAR, where
  # a stray byte would reach the provider's OAuth token request.
  printf '%s' "${value}" | add_secret_version "${secret}"
}

ensure_client_id() {
  store_credential "${1}" "${2}" "${3}" ""
}

ensure_client_secret() {
  store_credential "${1}" "${2}" "${3}" hidden
}

# Skip the executable body when sourced (e.g. by
# configure-tailscale-secrets.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

# Generating the client yields both values at once, in the browser, so a run
# before that legitimately leaves both secrets empty.
ensure_client_id tailscale-oauth-client-id \
  "Tailscale OAuth client ID" "${TAILSCALE_OAUTH_CLIENT_ID:-}"
ensure_client_secret tailscale-oauth-client-secret \
  "Tailscale OAuth client secret" "${TAILSCALE_OAUTH_CLIENT_SECRET:-}"
