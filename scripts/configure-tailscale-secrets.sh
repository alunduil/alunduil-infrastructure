#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Populates the Tailscale trust credential's client ID in the Secret Manager
# shell terraform/bootstrap/ declares. The value is written once, so re-running
# is a no-op and the bootstrap layer stays editable without it.

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-alunduil}"
SETUP_DOC="docs/how-to/create-tailscale-trust-credential.md"

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

# True when the operator is about to be asked: nothing supplied, and a terminal
# to ask at.
will_prompt() { [[ -z ${1} && -t 0 ]]; }

# Several trust credentials can exist on one tailnet, and the ID of the wrong
# one passes every check here — Secret Manager takes any string. The mismatch
# surfaces as a provider authentication failure a long way from the prompt.
print_credential_pointer() {
  cat >&2 <<EOF

The next value is the client ID of the OpenID Connect credential trusting this
repository's GitHub Actions, listed at
https://console.tailscale.com/admin/settings/trust-credentials.

If the credential does not exist yet, press Enter past the prompt and see
${SETUP_DOC}.

EOF
}

# A predicate that also reports, so a skipped secret says why in the bootstrap
# log rather than passing in silence.
already_stored() {
  secret_is_populated "${1}" || return 1

  echo "${1} already set."
}

skip_notice() {
  echo "Leaving ${1} empty; see ${SETUP_DOC}" >&2
}

# Precedence: the supplied value, else what the operator types, else nothing.
# read prompts on stderr, so only the answer reaches stdout.
#
# The ID is not a secret, so it is echoed as it is typed: a wrong answer is
# sticky — stored once, skipped by every later run — and this is the only place
# it can be proofread against the console.
ensure_client_id() {
  local secret="${1}" prompt="${2}" value="${3}"

  already_stored "${secret}" && return

  if will_prompt "${value}"; then
    print_credential_pointer
    read -r -p "${prompt} (Enter to skip): " value
  fi

  [[ -n ${value} ]] || {
    skip_notice "${secret}"
    return
  }

  # Tailscale documents no format beyond the ID being a single opaque token, so
  # a mangled paste is the only thing that can be caught here.
  [[ ${value} != *[[:space:]]* ]] || die "${prompt} must not contain whitespace"

  # No trailing newline: consumers read the value straight into a TF_VAR, where
  # a stray byte would reach the provider's token exchange.
  printf '%s' "${value}" | add_secret_version "${secret}"
}

# Skip the executable body when sourced (e.g. by
# configure-tailscale-secrets.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

command -v gcloud >/dev/null || die "gcloud CLI not found in PATH"

# Creating the credential is a browser action, so a run before that legitimately
# leaves the secret empty.
ensure_client_id tailscale-client-id \
  "Tailscale trust credential client ID" "${TAILSCALE_CLIENT_ID:-}"
