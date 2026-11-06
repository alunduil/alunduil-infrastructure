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
}

level_0_mermaid() {
  local fence='```'
  sed -n '/^## Level 0/,/^## /p' "${diagram}" \
    | sed -n "/^${fence}mermaid/,/^${fence}\$/p"
}

# Prints "element<TAB>category" for every pair STRIDE-per-element requires.
required_rows() {
  local mermaid element category
  mermaid="$(level_0_mermaid)"
  while IFS= read -r element; do
    for category in Spoofing Repudiation; do
      printf '%s\t%s\n' "${element}" "${category}"
    done
  done < <(grep -oE '^  [a-z_]+\["[^"]+"\]$' <<<"${mermaid}" | sed -E 's/.*\["(.*)"\]/\1/')
  while IFS= read -r element; do
    for category in Spoofing Tampering Repudiation "Information Disclosure" \
      "Denial of Service" "Elevation of Privilege"; do
      printf '%s\t%s\n' "${element}" "${category}"
    done
  done < <(grep -oE '^ +[a-z_]+\("[^"]+"\)$' <<<"${mermaid}" | sed -E 's/.*\("(.*)"\)/\1/')
  while IFS= read -r element; do
    for category in Tampering Repudiation "Information Disclosure" "Denial of Service"; do
      printf '%s\t%s\n' "${element}" "${category}"
    done
  done < <(grep -oE '\[\("[^"]+"\)\]$' <<<"${mermaid}" | sed -E 's/\[\("(.*)"\)\]/\1/')
  while IFS= read -r element; do
    for category in Tampering "Information Disclosure" "Denial of Service"; do
      printf '%s\t%s\n' "${element}" "${category}"
    done
  done < <(grep -oE '\|"F[0-9]+ [^"[]+' <<<"${mermaid}" | sed -E 's/\|"//; s/ +$//')
}

model_rows() {
  sed -n '/^### Level 0/,$p' "${model}" \
    | awk -F' \\| ' '/^\| / && !/^\| Element / && !/^\| --- / {
        sub(/^\| /, "", $1); print $1 "\t" $2
      }' | sort -u
}

@test "the threat model has a row for every element and category pair" {
  local required missing
  required="$(required_rows | sort -u)"
  # An empty parse would pass vacuously.
  [[ $(wc -l <<<"${required}") -gt 100 ]]

  missing="$(comm -23 <(printf '%s\n' "${required}") <(model_rows))"
  if [[ -n ${missing} ]]; then
    printf 'missing from threat-model-release-path.md:\n%s\n' "${missing}" >&2
    return 1
  fi
}

@test "the threat model has no row for anything outside the diagram" {
  local extra
  extra="$(comm -13 <(required_rows | sort -u) <(model_rows))"
  if [[ -n ${extra} ]]; then
    printf 'not required by release-path-data-flow.md:\n%s\n' "${extra}" >&2
    return 1
  fi
}

@test "a row claiming a status has the fields that status requires" {
  local bad
  bad="$(sed -n '/^### Level 0/,$p' "${model}" | awk -F' \\| ' '
    /^\| / && !/^\| Element / && !/^\| --- / {
      evidence = $7; sub(/ \|$/, "", evidence)
      if ($6 == "Mitigated" && ($5 == "—" || evidence == "—")) print
      if ($6 == "Not Applicable" && evidence == "—") print
      if ($6 == "Not Started" && $5 == "—") print
    }')"
  if [[ -n ${bad} ]]; then
    printf 'row missing a required field:\n%s\n' "${bad}" >&2
    return 1
  fi
}
