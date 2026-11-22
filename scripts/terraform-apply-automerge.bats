#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# A Renovate update to a path terraform-apply.yml triggers on automerges into
# an apply. renovate.json holds the path back, or terraform-plan.yml plans it
# so the required zero-change check gates the merge.

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

# Echo each path terraform-plan.yml's change detection diffs.
planned_paths() {
  awk '
    /git diff --quiet HEAD\^1 HEAD --/ { on = 1; next }
    on && /^ *then/ { exit }
    on { gsub(/[ \\]/, ""); if ($0 != "") print }
  ' "$1"
}

@test "every path terraform-apply.yml triggers on is held or planned" {
  local held planned missing=()
  held="$(jq -r '.packageRules[] | select(.automerge == false) | .matchFileNames[]?' \
    "${repo_root}/renovate.json")"
  planned="$(planned_paths "${repo_root}/.github/workflows/terraform-plan.yml")"
  # An empty read would pass vacuously.
  [[ -n ${planned} ]]

  local paths path
  mapfile -t paths < <(workflow_paths "${repo_root}/.github/workflows/terraform-apply.yml")
  [[ ${#paths[@]} -gt 0 ]]

  for path in "${paths[@]}"; do
    grep -qxF "${path}" <<<"${held}" && continue
    grep -qxF "${path%/\*\*}" <<<"${planned}" && continue
    missing+=("${path}")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'neither held in renovate.json nor planned: %s\n' "${missing[@]}" >&2
    return 1
  fi
}
