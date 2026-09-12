#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# kcov is the coverage tracer the bats CI job wraps around the suites. It
# publishes no release binaries and Ubuntu dropped the package after 22.04,
# so this builds from source. The build toolchain is the caller's to provide.
#
# Usage: scripts/install-kcov.sh --bin-dir DIR
set -euo pipefail

# GitHub's auto-generated tarballs carry no checksum asset, so this sha256 is
# pinned by hand and a version bump fails verification until it is refreshed.
# renovate: datasource=github-releases depName=SimonKagstrom/kcov
KCOV_VERSION="v43"
KCOV_SHA256="4cbba86af11f72de0c7514e09d59c7927ed25df7cebdad087f6d3623213b95bf" # pragma: allowlist secret
KCOV_TARBALL_URL="https://github.com/SimonKagstrom/kcov/archive/refs/tags/${KCOV_VERSION}.tar.gz"

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

# True when BIN is executable and already reports VERSION. The release tag
# carries a leading v; the binary reports its version without one.
installed_version_matches() {
  local bin="$1" version="$2"
  [[ -x ${bin} ]] && "${bin}" --version 2>/dev/null | grep -qF "${version#v}"
}

# Download the pinned tarball to ASSET and unpack it into SRC.
fetch_kcov_source() {
  local asset="$1" src="$2"
  curl -fsSL -o "${asset}" "${KCOV_TARBALL_URL}"
  echo "${KCOV_SHA256}  ${asset}" | sha256sum --check --quiet -
  mkdir -p "${src}"
  tar -xzf "${asset}" -C "${src}" --strip-components=1
}

build_kcov() {
  local src="$1" build="$2"
  cmake -S "${src}" -B "${build}" -G Ninja -DCMAKE_BUILD_TYPE=Release
  cmake --build "${build}" --parallel
}

# Install the built binary into BIN_DIR. kcov embeds its HTML report assets,
# so the binary is the whole install and cmake --install's share/ tree is
# unnecessary.
install_kcov() {
  local build="$1" bin_dir="$2"
  mkdir -p "${bin_dir}"
  install -m 0755 "${build}/src/kcov" "${bin_dir}/kcov"
}

# Skip the executable body when sourced (e.g. by install-kcov.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

if ! BIN_DIR="$(parse_bin_dir "$@")"; then
  exit 2
fi

if installed_version_matches "${BIN_DIR}/kcov" "${KCOV_VERSION}"; then
  echo "${PROGRAM}: kcov ${KCOV_VERSION} already installed at ${BIN_DIR}/kcov"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fetch_kcov_source "${TMP}/kcov-${KCOV_VERSION}.tar.gz" "${TMP}/src"
build_kcov "${TMP}/src" "${TMP}/build"
install_kcov "${TMP}/build" "${BIN_DIR}"
