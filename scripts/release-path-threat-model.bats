#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# The threat model joins the data flow diagram on element names, and a missing
# element-and-category row is indistinguishable from an oversight.

setup() {
  repo_root="${BATS_TEST_DIRNAME}/.."
  diagram="${repo_root}/docs/explanation/release-path-data-flow.md"
  model="${repo_root}/docs/explanation/threat-model-release-path.md"

  # The categories STRIDE-per-element applies to each element type.
  entity_categories=(Spoofing Repudiation)
  process_categories=(Spoofing Tampering Repudiation "Information Disclosure"
    "Denial of Service" "Elevation of Privilege")
  store_categories=(Tampering Repudiation "Information Disclosure"
    "Denial of Service")
  flow_categories=(Tampering "Information Disclosure" "Denial of Service")
}

level_0_diagram() {
  local fence='```'
  sed -n '/^## Level 0/,/^## /p' "${diagram}" \
    | sed -n "/^${fence}mermaid/,/^${fence}\$/p"
}

entities() {
  level_0_diagram | sed -nE 's/^ +[a-z_]+\["([^"]+)"\]$/\1/p'
}

processes() {
  level_0_diagram | sed -nE 's/^ +[a-z_]+\("([^"]+)"\)$/\1/p'
}

stores() {
  level_0_diagram | sed -nE 's/^ +[a-z_]+\[\("([^"]+)"\)\]$/\1/p'
}

# A flow's label ends where its bracketed credential starts.
flows() {
  level_0_diagram | grep -oE '\|"F[0-9]+ [^"[]+' | sed -E 's/^\|"//; s/ +$//'
}

# Pairs each element name on stdin with every category in the arguments.
with_categories() {
  local element category
  while IFS= read -r element; do
    for category in "$@"; do
      printf '%s\t%s\n' "${element}" "${category}"
    done
  done
}

required_rows() {
  {
    entities | with_categories "${entity_categories[@]}"
    processes | with_categories "${process_categories[@]}"
    stores | with_categories "${store_categories[@]}"
    flows | with_categories "${flow_categories[@]}"
  } | sort -u
}

level_0_table() {
  sed -n '/^### Level 0/,$p' "${model}" \
    | grep -E '^\| ' | grep -vE '^\| (Element|---) '
}

model_rows() {
  level_0_table | awk -F' \\| ' '{ sub(/^\| /, "", $1); print $1 "\t" $2 }' \
    | sort -u
}

@test "the threat model has a row for every element and category pair" {
  local required missing
  required="$(required_rows)"
  # An empty parse would pass vacuously.
  [[ -n ${required} ]]

  missing="$(comm -23 <(printf '%s\n' "${required}") <(model_rows))"
  if [[ -n ${missing} ]]; then
    printf 'missing from threat-model-release-path.md:\n%s\n' "${missing}" >&2
    return 1
  fi
}

@test "the threat model has no row for anything outside the diagram" {
  local extra
  extra="$(comm -13 <(required_rows) <(model_rows))"
  if [[ -n ${extra} ]]; then
    printf 'not required by release-path-data-flow.md:\n%s\n' "${extra}" >&2
    return 1
  fi
}

@test "a row claiming a status has the fields that status requires" {
  local bad
  bad="$(level_0_table | awk -F' \\| ' '{
    mitigation = $5; status = $6; evidence = $7
    sub(/ \|$/, "", evidence)
    if (status == "Mitigated" && (mitigation == "—" || evidence == "—")) print
    if (status == "Not Applicable" && evidence == "—") print
    if (status == "Not Started" && mitigation == "—") print
  }')"
  if [[ -n ${bad} ]]; then
    printf 'row missing a required field:\n%s\n' "${bad}" >&2
    return 1
  fi
}
