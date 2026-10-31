#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the pure helpers in install-terraform.sh (parse_bin_dir,
# lock_entry). The download and unzip are network side effects with no
# project-specific logic to assert.

setup() {
  # shellcheck source=install-terraform.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/install-terraform.sh"
}

# Write a mise.lock at PATH whose terraform linux-x64 checksum is CHECKSUM.
write_lock() {
  cat >"$1" <<EOF
[[tools.terraform]]
version = "1.2.3"
backend = "aqua:hashicorp/terraform"

[tools.terraform."platforms.linux-x64"]
checksum = "$2"
url = "https://example.test/terraform_1.2.3_linux_amd64.zip"
EOF
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

# --- lock_entry -----------------------------------------------------------

@test "lock_entry echoes the URL then the bare sha256" {
  write_lock "${BATS_TEST_TMPDIR}/mise.lock" "sha256:abc123"
  run lock_entry "${BATS_TEST_TMPDIR}/mise.lock" linux-x64
  [[ ${status} -eq 0 ]]
  [[ ${lines[0]} == https://example.test/terraform_1.2.3_linux_amd64.zip ]]
  [[ ${lines[1]} == abc123 ]]
}

@test "lock_entry rejects a platform the lock doesn't carry" {
  write_lock "${BATS_TEST_TMPDIR}/mise.lock" "sha256:abc123"
  run lock_entry "${BATS_TEST_TMPDIR}/mise.lock" macos-arm64
  [[ ${status} -ne 0 ]]
}

@test "lock_entry rejects a checksum that isn't sha256" {
  write_lock "${BATS_TEST_TMPDIR}/mise.lock" "blake3:abc123"
  run lock_entry "${BATS_TEST_TMPDIR}/mise.lock" linux-x64
  [[ ${status} -ne 0 ]]
}

@test "lock_entry reads the repo's mise.lock for the platform the script installs" {
  run lock_entry "${MISE_LOCK}" "${PLATFORM}"
  [[ ${status} -eq 0 ]]
  [[ ${lines[0]} == https://releases.hashicorp.com/terraform/* ]]
  [[ ${lines[1]} =~ ^[0-9a-f]{64}$ ]]
}
