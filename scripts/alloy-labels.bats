#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

setup() {
  # shellcheck source=lib/alloy-labels.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/lib/alloy-labels.sh"

  shopt -s nullglob
  templates=("${BATS_TEST_DIRNAME}"/../terraform/alunduil/*.alloy.tftpl)
  copy="${BATS_TEST_TMPDIR}/copy.alloy.tftpl"
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
      sed "/^\t\t\"${label}\" /d" "${template}" >"${copy}"
      run missing_labels "${copy}"
      [ "${status}" -eq 1 ]
      [[ "${output}" == *" ${label}" ]]
      [ "${#lines[@]}" -eq 1 ]
    done
  done
}

@test "each writer is checked on its own" {
  cat >"${copy}" <<'ALLOY'
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
  run missing_labels "${copy}"
  [ "${status}" -eq 1 ]
  [ "${lines[*]}" = "loki.write host loki.write collector_id loki.write pipeline" ]
}

@test "a pipeline named by a literal is reported" {
  sed 's/"[$]{pipeline}"/"other"/' "${templates[0]}" >"${copy}"
  run missing_labels "${copy}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *" pipeline" ]]
}

@test "a template without a writer is reported" {
  printf 'loki.source.journal "system" {\n}\n' >"${copy}"
  run missing_labels "${copy}"
  [ "${status}" -eq 1 ]
  [ "${output}" = "no writer" ]
}
