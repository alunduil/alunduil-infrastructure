#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

set -eux

ARCHIVE_DIRECTORY="${1:-/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/config-backups}"
RETENTION_DAYS="${2:-90}"
DATA_DIRECTORY="${3:-/data}"

ARCHIVE_PREFIX="truenas-config-"
DATABASE="freenas-v1.db"
SEED="pwenc_secret"

LIVE_DATABASE="${DATA_DIRECTORY}/${DATABASE}"

STAGING=$(mktemp -d)

cleanup() {
  rm -rf "${STAGING}"
}

trap cleanup EXIT

# Middleware writes to the database continuously, so reading it directly
# captures a torn copy. VACUUM INTO takes the copy in a single read pass
# without modifying the source.
snapshot_database() {
  # sqlite3 opens a missing database as a new empty one, which would archive a
  # valid-looking backup of nothing.
  [[ -f "${LIVE_DATABASE}" ]]

  sqlite3 "${LIVE_DATABASE}" "VACUUM INTO '${STAGING}/${DATABASE}'"
}

# Tarred from the source directory rather than copied, so the seed that
# decrypts every stored credential never lands in a temporary file.
create_archive() {
  local archive
  archive="${ARCHIVE_DIRECTORY}/${ARCHIVE_PREFIX}$(date +%F-%H%M%S).tar"

  tar -cf "${archive}" \
    -C "${STAGING}" "${DATABASE}" \
    -C "${DATA_DIRECTORY}" "${SEED}"
}

prune_archives() {
  find "${ARCHIVE_DIRECTORY}" -name "${ARCHIVE_PREFIX}*.tar" -mtime "+${RETENTION_DAYS}" -delete
}

snapshot_database
create_archive
prune_archives
