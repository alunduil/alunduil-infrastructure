# shellcheck shell=bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Secret Manager helpers for the scripts that fill the shells
# terraform/bootstrap/ declares. Sourced, not run.
#
# ensure_secret prompts for a secret and stores it. Re-running prompts only
# for an empty secret. A supplied value overwrites the stored one, which is how
# a credential is rotated. The caller sets SETUP_DOC, the how-to that creates
# the credential, and may redefine announce_pointer and read_answer after
# sourcing.

PROJECT_ID="${PROJECT_ID:-alunduil}"

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

needs_write() {
  local secret="$1" supplied="$2"
  [[ -n ${supplied} ]] || ! secret_is_populated "${secret}"
}

# Printed before the operator is asked for a value.
announce_pointer() { :; }

# read prompts on stderr, so only the answer reaches stdout.
read_answer() {
  local value
  read -r -p "${1} (Enter to skip): " value
  printf '%s' "${value}"
}

answer_for() {
  local prompt="$1" value="$2"
  [[ -n ${value} ]] || value="$(read_answer "${prompt}")"
  printf '%s' "${value}"
}

# transform validates the answer and prints the bytes to store. It runs before
# the write rather than piping into it, so a rejected answer stores nothing.
ensure_secret() {
  local secret="$1" prompt="$2" supplied="$3" transform="$4"

  needs_write "${secret}" "${supplied}" || {
    echo "${secret} already set."
    return 0
  }

  [[ -n ${supplied} ]] || announce_pointer

  local value
  value="$(answer_for "${prompt}" "${supplied}")"
  [[ -n ${value} ]] || {
    echo "Leaving ${secret} empty; see ${SETUP_DOC}" >&2
    return 0
  }

  value="$("${transform}" "${value}")" || return
  printf '%s' "${value}" | add_secret_version "${secret}"
}
