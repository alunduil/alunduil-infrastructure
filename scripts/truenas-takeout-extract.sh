#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

set -eux

DIRECTORY="${1:-/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/takeout}"

extract_file() {
  local file="${1}"
  local filename
  filename=$(basename "${file}")
  local directory

  if [[ "${filename}" == takeout-* ]]; then
    directory="${filename#takeout-}"
    directory="${directory%%-*}"
  elif [[ "${filename}" == chromeos-* ]]; then
    directory="${filename%.img*}"
    directory="${directory#chromeos-linux-}"
  else
    directory="misc"
  fi

  mkdir -p "${DIRECTORY}/${directory}"

  if [[ "${file}" == *.zst ]]; then
    # Use -- to prevent filenames starting with '-' from being interpreted as flags
    cp -- "${file}" "${DIRECTORY}/${directory}/"
  else
    tar --exclude "Takeout/Drive/home.alunduil.com" \
      --exclude "Takeout/Drive/Takeout" \
      -xf "${file}" -C "${DIRECTORY}/${directory}"
  fi
}

prune() {
  # ShellCheck SC2115: protective check to ensure DIRECTORY isn't empty/root
  if [[ -n "${DIRECTORY}" && "${DIRECTORY}" != "/" ]]; then
    find "${DIRECTORY}" -maxdepth 1 -type d ! -name tarballs -mtime +180 -exec rm -rf {} +
  fi
}

trap prune EXIT

# Check if directory exists before looping
if [[ -d "${DIRECTORY}/tarballs" ]]; then
  for file in "${DIRECTORY}/tarballs"/*; do
    # Handle case where directory is empty (glob returns literal '*')
    [[ -e "${file}" ]] || continue
    extract_file "${file}"
  done
fi
