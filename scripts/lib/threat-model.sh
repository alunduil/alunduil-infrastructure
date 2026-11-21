# shellcheck shell=bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Joins a threat model to its data flow diagram on element names, because a
# missing element-and-category row is indistinguishable from an oversight.

# STRIDE-per-element: the categories each element type is subject to.
entity_categories=(Spoofing Repudiation)
process_categories=(Spoofing Tampering Repudiation "Information Disclosure"
  "Denial of Service" "Elevation of Privilege")
store_categories=(Tampering Repudiation "Information Disclosure"
  "Denial of Service")
flow_categories=(Tampering "Information Disclosure" "Denial of Service")

level_0_diagram() {
  local diagram="$1" fence='```'
  sed -n '/^## Level 0/,/^## /p' "${diagram}" \
    | sed -n "/^${fence}mermaid/,/^${fence}\$/p"
}

# Mermaid's node shape carries the element type: entities are `id["…"]`,
# processes `id("…")`, and stores `id[("…")]`. open and close are regexes.
node_labels() {
  local diagram="$1" open="$2" close="$3"
  level_0_diagram "${diagram}" \
    | sed -nE "s/^ +[a-z_]+${open}\"([^\"]+)\"${close}\$/\\1/p"
}

# A flow's label ends where its bracketed credential starts.
flows() {
  local diagram="$1"
  level_0_diagram "${diagram}" \
    | grep -oE '\|"F[0-9]+ [^"[]+' | sed -E 's/^\|"//; s/ +$//'
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
  local diagram="$1"
  {
    node_labels "${diagram}" '\[' '\]' \
      | with_categories "${entity_categories[@]}"
    node_labels "${diagram}" '\(' '\)' \
      | with_categories "${process_categories[@]}"
    node_labels "${diagram}" '\[\(' '\)\]' \
      | with_categories "${store_categories[@]}"
    flows "${diagram}" | with_categories "${flow_categories[@]}"
  } | sort -u
}

level_0_table() {
  local model="$1"
  sed -n '/^### Level 0/,$p' "${model}" \
    | grep -E '^\| ' | grep -vE '^\| (Element|---) '
}

model_rows() {
  local model="$1"
  level_0_table "${model}" \
    | awk -F' \\| ' '{ sub(/^\| /, "", $1); print $1 "\t" $2 }' | sort -u
}

missing_rows() {
  local diagram="$1" model="$2" required
  required="$(required_rows "${diagram}")"
  # An empty parse would pass vacuously.
  [[ -n ${required} ]] || {
    printf 'no elements parsed from %s\n' "${diagram}" >&2
    return 1
  }
  comm -23 <(printf '%s\n' "${required}") <(model_rows "${model}")
}

extra_rows() {
  local diagram="$1" model="$2"
  comm -13 <(required_rows "${diagram}") <(model_rows "${model}")
}

incomplete_rows() {
  local model="$1"
  level_0_table "${model}" | awk -F' \\| ' -v none='—' '{
    mitigation = $5; status = $6; evidence = $7
    sub(/ \|$/, "", evidence)
    if (status == "Mitigated" && (mitigation == none || evidence == none)) print
    if (status == "Not Applicable" && evidence == none) print
    if (status == "Not Started" && mitigation == none) print
    if (status !~ /^(Mitigated|Not Applicable|Not Started)$/) print
  }'
}
