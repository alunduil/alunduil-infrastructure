#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

setup() {
  shopt -s nullglob
  templates=("${BATS_TEST_DIRNAME}"/../terraform/alunduil/*.alloy.tftpl)
  writers=()
  local template
  for template in "${templates[@]}"; do
    grep -q external_labels "${template}" && writers+=("${template}")
  done
  fixture="${BATS_TEST_TMPDIR}/fixture.alloy.tftpl"
}

label_violations() {
  awk -f "${BATS_TEST_DIRNAME}/lib/alloy-labels.awk" "$1"
}

# Takes a glob for each reported line, in order.
assert_reports() {
  local line
  run label_violations "${fixture}"
  [ "${status}" -eq 1 ]
  [ "${#lines[@]}" -eq "$#" ]
  for line in "${lines[@]}"; do
    # shellcheck disable=SC2053
    [[ ${line} == $1 ]]
    shift
  done
}

@test "every pipeline template sets every label" {
  local template found failed=0
  ((${#templates[@]} > 0))
  for template in "${templates[@]}"; do
    if ! found="$(label_violations "${template}")"; then
      printf '%s:\n%s\n' "${template##*/}" "${found}" >&2
      failed=1
    fi
  done
  ((failed == 0))
}

@test "removing any label from any writer is reported" {
  local template label
  ((${#writers[@]} > 0))
  for template in "${writers[@]}"; do
    for label in host collector_id pipeline; do
      sed "/^\t\t\"${label}\" /d" "${template}" >"${fixture}"
      assert_reports "* ${label}"
    done
  done
}

@test "each writer is checked on its own" {
  cat >"${fixture}" <<'ALLOY'
prometheus.remote_write "default" {
	external_labels = {
		"host"         = "a",
		"collector_id" = argument.attributes.value["collector.ID"],
		"pipeline"     = "${pipeline}",
	}
}

loki.write "default" {
	endpoint {
	}
}
ALLOY
  assert_reports "loki.write host" "loki.write collector_id" "loki.write pipeline"
}

@test "a literal collector_id or pipeline is reported" {
  local label
  for label in collector_id pipeline; do
    sed -E "s/^(\t\t\"${label}\" *= ).*/\1\"other\",/" "${writers[0]}" >"${fixture}"
    assert_reports "* ${label}"
  done
}

@test "a template without a writer is reported" {
  printf 'loki.source.journal "system" {\n}\n' >"${fixture}"
  assert_reports "no writer"
}

@test "an embedded shared writer counts as a writer" {
  local placeholder
  for placeholder in loki_write prometheus_remote_write; do
    printf '%s\n' 'loki.source.journal "system" {' '}' '' "\${${placeholder}}" >"${fixture}"
    run label_violations "${fixture}"
    [ "${status}" -eq 0 ]
  done
}
