#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# The download and unzip carry no project-specific logic, so only
# terraform_lock_entry is tested.

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

@test "terraform_lock_entry echoes the URL and the bare sha256" {
  write_lock "${BATS_TEST_TMPDIR}/mise.lock" "sha256:abc123"
  run terraform_lock_entry "${BATS_TEST_TMPDIR}/mise.lock" linux-x64
  [[ ${status} -eq 0 ]]
  [[ ${output} == "https://example.test/terraform_1.2.3_linux_amd64.zip abc123" ]]
}

@test "terraform_lock_entry rejects a platform the lock doesn't carry" {
  write_lock "${BATS_TEST_TMPDIR}/mise.lock" "sha256:abc123"
  run terraform_lock_entry "${BATS_TEST_TMPDIR}/mise.lock" macos-arm64
  [[ ${status} -ne 0 ]]
}

@test "terraform_lock_entry rejects a checksum that isn't sha256" {
  write_lock "${BATS_TEST_TMPDIR}/mise.lock" "blake3:abc123"
  run terraform_lock_entry "${BATS_TEST_TMPDIR}/mise.lock" linux-x64
  [[ ${status} -ne 0 ]]
}

@test "terraform_lock_entry reads the repo's mise.lock for the platform the script installs" {
  run terraform_lock_entry "${MISE_LOCK}" "${PLATFORM}"
  [[ ${status} -eq 0 ]]
  [[ ${output} =~ ^https://releases\.hashicorp\.com/terraform/[^[:space:]]+\ [0-9a-f]{64}$ ]]
}
