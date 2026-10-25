#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# A path terraform-apply.yml triggers on but renovate.json doesn't hold back
# would automerge straight into an apply.

setup() {
  repo_root="${BATS_TEST_DIRNAME}/.."
}

# Echo each entry of the first paths: list in a workflow, unquoted.
workflow_paths() {
  awk '
    /^ *paths:/ { in_paths = 1; next }
    in_paths && /^ *- / {
      sub(/^ *- */, ""); gsub(/["'\'']/, ""); print; next
    }
    in_paths { exit }
  ' "$1"
}

@test "renovate.json holds back every path terraform-apply.yml triggers on" {
  local held missing=()
  held="$(jq -r '.packageRules[] | select(.automerge == false) | .matchFileNames[]?' \
    "${repo_root}/renovate.json")"

  local paths path
  mapfile -t paths < <(workflow_paths "${repo_root}/.github/workflows/terraform-apply.yml")
  # An empty read would pass vacuously.
  [[ ${#paths[@]} -gt 0 ]]

  for path in "${paths[@]}"; do
    grep -qxF "${path}" <<<"${held}" || missing+=("${path}")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'missing from renovate.json matchFileNames: %s\n' "${missing[@]}" >&2
    return 1
  fi
}
