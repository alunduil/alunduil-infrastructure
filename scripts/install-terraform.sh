#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Installs the Terraform that mise.lock pins, for jobs that can't run
# jdx/mise-action, such as the shared hook-fix workflow's setup command.
# Reading the lock's URL and checksum keeps one Terraform pin, which Renovate
# bumps.
#
# Usage: scripts/install-terraform.sh --bin-dir DIR
set -euo pipefail

PLATFORM="linux-x64"
MISE_LOCK="$(dirname "${BASH_SOURCE[0]}")/../mise.lock"

# $0 is the bats binary once this file is sourced, so diagnostics name the
# file itself rather than whatever is running it.
PROGRAM="${BASH_SOURCE[0]##*/}"

# Echo the --bin-dir value; return 2 when the arguments do not supply one.
# Diagnostics go to stderr because the caller takes this function's stdout
# as the directory.
parse_bin_dir() {
  local bin_dir=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bin-dir)
        if [[ $# -lt 2 ]]; then
          echo "${PROGRAM}: --bin-dir requires an argument" >&2
          return 2
        fi
        bin_dir="$2"
        shift 2
        ;;
      *)
        echo "${PROGRAM}: unknown argument: $1" >&2
        return 2
        ;;
    esac
  done

  if [[ -z ${bin_dir} ]]; then
    echo "${PROGRAM}: --bin-dir DIR required" >&2
    return 2
  fi

  printf '%s\n' "${bin_dir}"
}

# Echo Terraform's download URL and sha256 for PLATFORM from LOCK, one per
# line. Fails when the lock has no such entry or its checksum isn't sha256.
lock_entry() {
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
print(url)
print(digest)
EOF
}

# Skip the executable body when sourced (e.g. by install-terraform.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

if ! BIN_DIR="$(parse_bin_dir "$@")"; then
  exit 2
fi

ENTRY="$(lock_entry "${MISE_LOCK}" "${PLATFORM}")"
URL="${ENTRY%%$'\n'*}"
SHA256="${ENTRY#*$'\n'}"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

curl -fsSL -o "${TMP}/terraform.zip" "${URL}"
echo "${SHA256}  ${TMP}/terraform.zip" | sha256sum --check --quiet -
mkdir -p "${BIN_DIR}"
unzip -o -q "${TMP}/terraform.zip" terraform -d "${BIN_DIR}"
