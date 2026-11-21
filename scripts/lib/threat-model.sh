# shellcheck shell=bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Joins a threat model to its data flow diagram on element names, because a
# missing element-and-category row is indistinguishable from an oversight.
# Callers set `diagram` and `model` to the two documents' paths.

# STRIDE-per-element: the categories each element type is subject to.
entity_categories=(Spoofing Repudiation)
process_categories=(Spoofing Tampering Repudiation "Information Disclosure"
  "Denial of Service" "Elevation of Privilege")
store_categories=(Tampering Repudiation "Information Disclosure"
  "Denial of Service")
flow_categories=(Tampering "Information Disclosure" "Denial of Service")

level_0_diagram() {
  local fence='```'
  sed -n '/^## Level 0/,/^## /p' "${diagram:?}" \
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
  sed -n '/^### Level 0/,$p' "${model:?}" \
    | grep -E '^\| ' | grep -vE '^\| (Element|---) '
}

model_rows() {
  level_0_table | awk -F' \\| ' '{ sub(/^\| /, "", $1); print $1 "\t" $2 }' \
    | sort -u
}

missing_rows() {
  local required
  required="$(required_rows)"
  # An empty parse would pass vacuously.
  [[ -n ${required} ]] || {
    printf 'no elements parsed from %s\n' "${diagram}" >&2
    return 1
  }
  comm -23 <(printf '%s\n' "${required}") <(model_rows)
}

extra_rows() {
  comm -13 <(required_rows) <(model_rows)
}

incomplete_rows() {
  level_0_table | awk -F' \\| ' '{
    mitigation = $5; status = $6; evidence = $7
    sub(/ \|$/, "", evidence)
    if (status == "Mitigated" && (mitigation == "—" || evidence == "—")) print
    if (status == "Not Applicable" && evidence == "—") print
    if (status == "Not Started" && mitigation == "—") print
  }'
}
