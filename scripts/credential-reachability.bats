#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# A credential the graph omits reads as one that reaches nothing, so the page
# and the register have to name the same set.

setup() {
  repo_root="${BATS_TEST_DIRNAME}/.."
  register="${repo_root}/docs/reference/asset-register.md"
  page="${repo_root}/docs/explanation/credential-reachability.md"
  id_pattern='[A-Z]-[0-9]+'
}

registered_ids() {
  grep -oE "^#{3,4} ${id_pattern}|^\| ${id_pattern} \|" "${register}" \
    | grep -oE "${id_pattern}" | sort -u
}

@test "the reachability page names every credential in the register" {
  local credentials missing=()
  mapfile -t credentials < <(registered_ids | grep '^C-')
  # An empty read would pass vacuously.
  [[ ${#credentials[@]} -gt 0 ]]

  local id
  for id in "${credentials[@]}"; do
    grep -qw -- "${id}" "${page}" || missing+=("${id}")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'missing from credential-reachability.md: %s\n' "${missing[@]}" >&2
    return 1
  fi
}

@test "every ID on the reachability page exists in the register" {
  local known ids unknown=()
  known="$(registered_ids)"
  mapfile -t ids < <(grep -oE "\b${id_pattern}\b" "${page}" | sort -u)
  [[ ${#ids[@]} -gt 0 ]]

  local id
  for id in "${ids[@]}"; do
    grep -qxF -- "${id}" <<<"${known}" || unknown+=("${id}")
  done

  if [[ ${#unknown[@]} -gt 0 ]]; then
    printf 'not in asset-register.md: %s\n' "${unknown[@]}" >&2
    return 1
  fi
}
