#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

set -eux

DIRECTORY="${1:-/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/config-backups}"
RETENTION_DAYS="${2:-90}"
DATA_DIRECTORY="${3:-/data}"

ARCHIVE_PREFIX="truenas-config-"
DATABASE="freenas-v1.db"
SEED="pwenc_secret"

STAGING=$(mktemp -d)

cleanup() {
  rm -rf "${STAGING}"
}

trap cleanup EXIT

# Middleware writes to the database continuously, so reading it directly
# captures a torn copy. VACUUM INTO takes the copy in a single read pass
# without modifying the source.
snapshot_database() {
  python3 -c 'import sqlite3, sys
connection = sqlite3.connect(sys.argv[1])
connection.execute("VACUUM INTO ?", (sys.argv[2],))
connection.close()' "${DATA_DIRECTORY}/${DATABASE}" "${STAGING}/${DATABASE}"
}

# Tarred from the source directory rather than copied, so the seed that
# decrypts every stored credential never lands in a temporary file.
create_archive() {
  local archive
  archive="${DIRECTORY}/${ARCHIVE_PREFIX}$(date +%F-%H%M%S).tar"

  tar -cf "${archive}" \
    -C "${STAGING}" "${DATABASE}" \
    -C "${DATA_DIRECTORY}" "${SEED}"
}

prune_archives() {
  find "${DIRECTORY}" -name "${ARCHIVE_PREFIX}*.tar" -mtime "+${RETENTION_DAYS}" -delete
}

snapshot_database
create_archive
prune_archives
