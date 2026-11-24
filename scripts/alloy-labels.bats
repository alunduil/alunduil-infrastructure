#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

setup() {
  # shellcheck source=lib/alloy-labels.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/lib/alloy-labels.sh"

  shopt -s nullglob
  templates=("${BATS_TEST_DIRNAME}"/../terraform/alunduil/*.alloy.tftpl)
  fixture="${BATS_TEST_TMPDIR}/fixture.alloy.tftpl"
}

# assert_reports takes a pattern for the fixture's only line of output.
assert_reports() {
  run missing_labels "${fixture}"
  [ "${status}" -eq 1 ]
  [ "${#lines[@]}" -eq 1 ]
  # shellcheck disable=SC2053
  [[ ${output} == $1 ]]
}

@test "every pipeline template sets every label" {
  local template found failed=0
  ((${#templates[@]} > 0))
  for template in "${templates[@]}"; do
    if ! found="$(missing_labels "${template}")"; then
      printf '%s:\n%s\n' "${template##*/}" "${found}" >&2
      failed=1
    fi
  done
  ((failed == 0))
}

@test "removing any label from any template is reported" {
  local template label
  for template in "${templates[@]}"; do
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
  run missing_labels "${fixture}"
  [ "${status}" -eq 1 ]
  [ "${lines[*]}" = "loki.write host loki.write collector_id loki.write pipeline" ]
}

@test "a pipeline named by a literal is reported" {
  sed 's/"[$]{pipeline}"/"other"/' "${templates[0]}" >"${fixture}"
  assert_reports "* pipeline"
}

@test "a template without a writer is reported" {
  printf 'loki.source.journal "system" {\n}\n' >"${fixture}"
  assert_reports "no writer"
}
