#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the pure helpers in export-terraform-credentials.sh: the
# per-line masking and the GITHUB_ENV heredoc contract. The gcloud-touching
# paths (access, export_secret) are not exercised — the plan workflow covers
# them against live Secret Manager on every pull request.

setup() {
  GITHUB_ENV="${BATS_TEST_TMPDIR}/github_env"
  : >"${GITHUB_ENV}"
  # shellcheck source=export-terraform-credentials.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/export-terraform-credentials.sh"
}

# Stands in for the Git Sync PEM: several lines, no trailing newline, since
# command substitution strips it before the value ever reaches export_var.
multiline() {
  printf -- 'HEADER\nAAAA\nBBBB\nFOOTER'
}

# --- mask -----------------------------------------------------------------

@test "mask registers one add-mask per line" {
  run mask <<<"$(multiline)"
  [[ ${status} -eq 0 ]]
  [[ ${#lines[@]} -eq 4 ]]
  [[ ${lines[0]} == '::add-mask::HEADER' ]]
  [[ ${lines[1]} == '::add-mask::AAAA' ]]
  [[ ${lines[3]} == '::add-mask::FOOTER' ]]
}

@test "mask skips blank lines rather than registering an empty mask" {
  run mask <<<$'AAAA\n\nBBBB'
  [[ ${status} -eq 0 ]]
  [[ ${#lines[@]} -eq 2 ]]
  [[ ${lines[0]} == '::add-mask::AAAA' ]]
  [[ ${lines[1]} == '::add-mask::BBBB' ]]
}

@test "mask emits nothing for an empty value" {
  run mask <<<""
  [[ ${status} -eq 0 ]]
  [[ -z ${output} ]]
}

# --- export_var -----------------------------------------------------------

@test "export_var masks a multi-line value before writing it" {
  run export_var TF_VAR_key "$(multiline)"
  [[ ${status} -eq 0 ]]
  [[ ${#lines[@]} -eq 4 ]]
  [[ ${lines[1]} == '::add-mask::AAAA' ]]
}

@test "export_var masks a single-line value" {
  run export_var TF_VAR_token "s3cr3t"
  [[ ${output} == '::add-mask::s3cr3t' ]]
}

@test "export_var writes the heredoc form GITHUB_ENV parses" {
  export_var TF_VAR_token "s3cr3t"
  [[ "$(cat "${GITHUB_ENV}")" == $'TF_VAR_token<<__TFVAR__\ns3cr3t\n__TFVAR__' ]]
}

@test "export_var round-trips a multi-line value between the delimiters" {
  export_var TF_VAR_key "$(multiline)"
  # Everything between the delimiters is the value, interior lines intact.
  local body
  body="$(sed -n '/^TF_VAR_key<<__TFVAR__$/,/^__TFVAR__$/{//!p}' "${GITHUB_ENV}")"
  [[ ${body} == "$(multiline)" ]]
}

@test "export_var terminates the heredoc for a value with no trailing newline" {
  export_var TF_VAR_key "$(multiline)"
  [[ "$(tail -n 1 "${GITHUB_ENV}")" == '__TFVAR__' ]]
}

@test "export_var appends, leaving earlier entries intact" {
  export_var TF_VAR_first one
  export_var TF_VAR_second two
  grep -Fxq 'TF_VAR_first<<__TFVAR__' "${GITHUB_ENV}"
  grep -Fxq 'TF_VAR_second<<__TFVAR__' "${GITHUB_ENV}"
}
