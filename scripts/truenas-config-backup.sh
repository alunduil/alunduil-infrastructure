#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

set -eux

DIRECTORY="${1:-/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/config-backups}"
RETENTION_DAYS="${2:-90}"

SNAPSHOT=$(mktemp -d)

cleanup() {
  rm -rf "${SNAPSHOT}"
}

trap cleanup EXIT

# Middleware writes to freenas-v1.db continuously, so reading it directly
# captures a torn database. VACUUM INTO produces the copy in a single read pass
# without modifying the source, which is how middleware's own config.save works.
python3 -c 'import sqlite3, sys
connection = sqlite3.connect("/data/freenas-v1.db")
connection.execute("VACUUM INTO ?", (sys.argv[1],))
connection.close()' "${SNAPSHOT}/freenas-v1.db"

# pwenc_secret is tarred from /data rather than copied, so the seed that
# decrypts every credential in the database never lands in a temporary file.
tar -cf "${DIRECTORY}/truenas-config-$(date +%F-%H%M%S).tar" \
  -C "${SNAPSHOT}" freenas-v1.db \
  -C /data pwenc_secret

find "${DIRECTORY}" -name 'truenas-config-*.tar' -mtime "+${RETENTION_DAYS}" -delete
