# shellcheck shell=bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Prompts for a GitHub App's credentials and stores them in the Secret Manager
# shells terraform/bootstrap/ declares. Re-running prompts only for an empty
# secret. A supplied value overwrites the stored one, which is how a key is
# rotated. Sourced, not run.
#
# The caller sets APP_NAME, the App's name on GitHub, and SETUP_DOC, the how-to
# that creates it.

# shellcheck source=scripts/lib/secret-manager.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/secret-manager.sh"

die() {
  echo "error: $*" >&2
  exit 1
}

needs_write() {
  local secret="$1" supplied="$2"
  [[ -n ${supplied} ]] || ! secret_is_populated "${secret}"
}

# read prompts on stderr, so only the answer reaches stdout.
answer_for() {
  local prompt="$1" value="$2"
  [[ -n ${value} ]] || read -r -p "${prompt} (Enter to skip): " value
  printf '%s' "${value}"
}

check_digits() {
  # A wrong App or installation ID surfaces far from here, as a refused push or
  # an opaque authentication failure, so catch a mistyped one now.
  [[ ${1} =~ ^[0-9]+$ ]] || die "expected digits, got '${1}'"
  printf '%s' "${1}"
}

read_private_key() {
  # A path typed at the prompt arrives with its tilde unexpanded.
  local path="${1/#\~/${HOME}}"

  [[ -r ${path} ]] || die "cannot read '${path}'"
  grep -q -- '-----BEGIN .*PRIVATE KEY-----' "${path}" \
    || die "'${path}' is not a PEM private key"
  cat "${path}"
}

pointer_shown=""

announce_app_once() {
  [[ -z ${pointer_shown} ]] || return 0

  pointer_shown=yes
  cat >&2 <<EOF

The next values belong to the GitHub App named ${APP_NAME}. If it does
not exist yet, see ${SETUP_DOC}.

EOF
}

# transform validates the answer and prints the bytes to store. It runs before
# the write rather than piping into it, so a rejected answer stores nothing.
ensure_secret() {
  local secret="$1" prompt="$2" supplied="$3" transform="$4"

  needs_write "${secret}" "${supplied}" || {
    echo "${secret} already set."
    return 0
  }

  [[ -n ${supplied} ]] || announce_app_once

  local value
  value="$(answer_for "${prompt}" "${supplied}")"
  [[ -n ${value} ]] || {
    echo "Leaving ${secret} empty; see ${SETUP_DOC}" >&2
    return 0
  }

  value="$("${transform}" "${value}")" || return
  printf '%s' "${value}" | add_secret_version "${secret}"
}
