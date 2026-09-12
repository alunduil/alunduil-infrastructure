#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Installs kcov, the coverage tracer the bats CI job wraps around the suites.
# kcov publishes no release binaries and Ubuntu dropped the package after
# 22.04, so this builds from source. The build toolchain (a C++ compiler,
# cmake, ninja, and kcov's -dev dependencies) is the caller's to provide.
#
# Usage: scripts/install-kcov.sh --bin-dir DIR
set -euo pipefail

# GitHub's auto-generated tarballs carry no checksum asset, so this sha256 is
# pinned by hand and a version bump fails verification until it is refreshed.
# renovate: datasource=github-releases depName=SimonKagstrom/kcov
KCOV_VERSION="v43"
KCOV_SHA256="4cbba86af11f72de0c7514e09d59c7927ed25df7cebdad087f6d3623213b95bf" # pragma: allowlist secret

BIN_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bin-dir)
      if [[ $# -lt 2 ]]; then
        echo "${0##*/}: --bin-dir requires an argument" >&2
        exit 2
      fi
      BIN_DIR="$2"
      shift 2
      ;;
    *)
      echo "${0##*/}: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z ${BIN_DIR} ]]; then
  echo "${0##*/}: --bin-dir DIR required" >&2
  exit 2
fi

bin="${BIN_DIR}/kcov"
# The release tag carries a leading v; the binary reports its version without.
if [[ -x ${bin} ]] && "${bin}" --version 2>/dev/null | grep -qF "${KCOV_VERSION#v}"; then
  echo "${0##*/}: kcov ${KCOV_VERSION} already installed at ${bin}"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

asset="${tmp}/kcov-${KCOV_VERSION}.tar.gz"
curl -fsSL -o "${asset}" \
  "https://github.com/SimonKagstrom/kcov/archive/refs/tags/${KCOV_VERSION}.tar.gz"
echo "${KCOV_SHA256}  ${asset}" | sha256sum --check --quiet -

src="${tmp}/src"
mkdir -p "${src}"
tar -xzf "${asset}" -C "${src}" --strip-components=1

cmake -S "${src}" -B "${tmp}/build" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "${tmp}/build" --parallel

# kcov embeds its HTML report assets, so these two binaries are the whole
# install and cmake --install's share/ tree is unnecessary.
mkdir -p "${BIN_DIR}"
install -m 0755 "${tmp}/build/src/kcov" "${bin}"
install -m 0755 "${tmp}/build/src/kcov-system-daemon" "${BIN_DIR}/kcov-system-daemon"
