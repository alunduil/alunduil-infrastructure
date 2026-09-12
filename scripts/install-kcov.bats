#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the pure helpers in install-kcov.sh (parse_bin_dir,
# installed_version_matches). The fetch, build, and install steps are not
# exercised: they are network and toolchain side effects with no
# project-specific logic to assert, and the bats CI job runs them for real on
# every push.

setup() {
  # shellcheck source=install-kcov.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/install-kcov.sh"
}

# Write a stub at PATH reporting VERSION the way `kcov --version` does.
stub_kcov() {
  printf '#!/bin/bash\necho "kcov %s"\n' "$2" >"$1"
  chmod +x "$1"
}

# --- parse_bin_dir --------------------------------------------------------

@test "parse_bin_dir echoes the directory" {
  run parse_bin_dir --bin-dir /opt/bin
  [[ ${status} -eq 0 ]]
  [[ ${output} == /opt/bin ]]
}

@test "parse_bin_dir rejects a missing --bin-dir" {
  run parse_bin_dir
  [[ ${status} -eq 2 ]]
}

@test "parse_bin_dir rejects --bin-dir without a value" {
  run parse_bin_dir --bin-dir
  [[ ${status} -eq 2 ]]
}

@test "parse_bin_dir rejects an unknown argument" {
  run parse_bin_dir --bogus
  [[ ${status} -eq 2 ]]
}

@test "parse_bin_dir keeps diagnostics off stdout" {
  # The caller reads stdout by command substitution, so a diagnostic written
  # there would be taken for a directory.
  local stdout
  stdout="$(parse_bin_dir --bogus 2>/dev/null)" || true
  [[ -z ${stdout} ]]
}

@test "parse_bin_dir takes the last --bin-dir" {
  run parse_bin_dir --bin-dir /first --bin-dir /second
  [[ ${status} -eq 0 ]]
  [[ ${output} == /second ]]
}

# --- installed_version_matches --------------------------------------------

@test "installed_version_matches ignores the tag's leading v" {
  stub_kcov "${BATS_TEST_TMPDIR}/kcov" 43
  run installed_version_matches "${BATS_TEST_TMPDIR}/kcov" v43
  [[ ${status} -eq 0 ]]
}

@test "installed_version_matches rejects a different version" {
  stub_kcov "${BATS_TEST_TMPDIR}/kcov" 42
  run installed_version_matches "${BATS_TEST_TMPDIR}/kcov" v43
  [[ ${status} -ne 0 ]]
}

@test "installed_version_matches rejects a binary that is not there" {
  run installed_version_matches "${BATS_TEST_TMPDIR}/absent" v43
  [[ ${status} -ne 0 ]]
}
