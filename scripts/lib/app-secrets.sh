# shellcheck shell=bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Fits secret-manager.sh's ensure_secret to a GitHub App's credentials: a
# pointer naming the App, and transforms for its ID and private key. Sourced,
# not run.
#
# The caller sets APP_NAME, the App's name on GitHub, and SETUP_DOC, the how-to
# that creates it.

# shellcheck source=scripts/lib/secret-manager.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/secret-manager.sh"

check_digits() {
  # A wrong ID fails only once the App is used, far from here, so catch a
  # mistyped one now.
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

announce_pointer() {
  [[ -z ${pointer_shown} ]] || return 0

  pointer_shown=yes
  cat >&2 <<EOF

The next values belong to the GitHub App named ${APP_NAME}. If it does
not exist yet, see ${SETUP_DOC}.

EOF
}
