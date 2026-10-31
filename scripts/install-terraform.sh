#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Installs the Terraform that mise.lock pins onto a GitHub Actions job's PATH,
# for jobs that can't run jdx/mise-action, such as the shared hook-fix
# workflow's setup command. Reading the lock's URL and checksum keeps one
# Terraform pin, which Renovate bumps.
#
# Usage: scripts/install-terraform.sh
set -euo pipefail

PLATFORM="linux-x64"
MISE_LOCK="$(dirname "${BASH_SOURCE[0]}")/../mise.lock"

# Echo Terraform's download URL and sha256 for PLATFORM from LOCK on one
# line. Fails when the lock has no such entry or its checksum isn't sha256.
terraform_lock_entry() {
  local lock="$1" platform="$2"
  python3 - "${lock}" "${platform}" <<'EOF'
import sys
import tomllib

lock, platform = sys.argv[1:]
with open(lock, "rb") as f:
    tools = tomllib.load(f).get("tools", {})
try:
    entry = tools["terraform"][0][f"platforms.{platform}"]
    url, checksum = entry["url"], entry["checksum"]
except (KeyError, IndexError):
    sys.exit(f"no terraform {platform} entry in {lock}")
algorithm, _, digest = checksum.partition(":")
if algorithm != "sha256":
    sys.exit(f"terraform {platform} checksum in {lock} is not sha256")
print(url, digest)
EOF
}

# Skip the executable body when sourced (e.g. by install-terraform.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

: "${RUNNER_TEMP:?run this in a GitHub Actions job}"
: "${GITHUB_PATH:?run this in a GitHub Actions job}"

ENTRY="$(terraform_lock_entry "${MISE_LOCK}" "${PLATFORM}")"
read -r URL SHA256 <<<"${ENTRY}"

BIN_DIR="${RUNNER_TEMP}/bin"
ZIP="${RUNNER_TEMP}/terraform.zip"
curl -fsSL -o "${ZIP}" "${URL}"
echo "${SHA256}  ${ZIP}" | sha256sum --check --quiet -
mkdir -p "${BIN_DIR}"
unzip -o -q "${ZIP}" terraform -d "${BIN_DIR}"
echo "${BIN_DIR}" >>"${GITHUB_PATH}"
