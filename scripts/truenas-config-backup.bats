#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Tests for truenas-config-backup.sh. Every function touches the filesystem, so
# the script runs as a subprocess against a substituted source directory rather
# than being sourced for unit tests. The Cloud Sync task that invokes it and the
# transfer that follows are not exercised here.

setup() {
  SOURCE="${BATS_TEST_TMPDIR}/data"
  DEST="${BATS_TEST_TMPDIR}/config-backups"
  mkdir -p "${SOURCE}" "${DEST}"

  sqlite3 "${SOURCE}/freenas-v1.db" \
    "CREATE TABLE settings (key, value); INSERT INTO settings VALUES ('a', '1'), ('b', '2');"
  printf 'seed\n' >"${SOURCE}/pwenc_secret"

  # mktemp -d honours TMPDIR, so staging lands somewhere assertable.
  TMPDIR="${BATS_TEST_TMPDIR}/tmp"
  export TMPDIR
  mkdir -p "${TMPDIR}"
}

backup() {
  "${BATS_TEST_DIRNAME}/truenas-config-backup.sh" "${DEST}" "${1:-90}" "${SOURCE}"
}

extract() {
  local -a archives=("${DEST}"/truenas-config-*.tar)
  tar -xf "${archives[0]}" -C "${BATS_TEST_TMPDIR}"
}

# --- archive contents -----------------------------------------------------

@test "archive carries the database and the seed" {
  backup

  local -a archives=("${DEST}"/truenas-config-*.tar)
  run tar -tf "${archives[0]}"
  [[ ${status} -eq 0 ]]
  [[ ${#lines[@]} -eq 2 ]]
  [[ ${lines[0]} == 'freenas-v1.db' ]]
  [[ ${lines[1]} == 'pwenc_secret' ]]
}

@test "archived database is readable and keeps its rows" {
  backup
  extract

  [[ "$(sqlite3 "${BATS_TEST_TMPDIR}/freenas-v1.db" 'PRAGMA integrity_check')" == 'ok' ]]
  [[ "$(sqlite3 "${BATS_TEST_TMPDIR}/freenas-v1.db" 'SELECT count(*) FROM settings')" == '2' ]]
}

@test "archived seed matches the source" {
  backup
  extract

  [[ "$(cat "${BATS_TEST_TMPDIR}/pwenc_secret")" == 'seed' ]]
}

# --- retention ------------------------------------------------------------

@test "prunes archives past the retention window" {
  touch -d '100 days ago' "${DEST}/truenas-config-2000-01-01-000000.tar"

  backup

  [[ ! -e "${DEST}/truenas-config-2000-01-01-000000.tar" ]]
}

@test "keeps archives inside the retention window" {
  touch -d '10 days ago' "${DEST}/truenas-config-2000-01-01-000000.tar"

  backup

  [[ -e "${DEST}/truenas-config-2000-01-01-000000.tar" ]]
}

@test "retention window is configurable" {
  touch -d '10 days ago' "${DEST}/truenas-config-2000-01-01-000000.tar"

  backup 5

  [[ ! -e "${DEST}/truenas-config-2000-01-01-000000.tar" ]]
}

@test "prune is scoped to the archive prefix" {
  touch -d '100 days ago' "${DEST}/other-config-2000-01-01-000000.tar"
  touch -d '100 days ago' "${DEST}/backup.sh"

  backup

  [[ -e "${DEST}/other-config-2000-01-01-000000.tar" ]]
  [[ -e "${DEST}/backup.sh" ]]
}

# --- failure modes --------------------------------------------------------

@test "staging directory is removed once the archive is written" {
  backup

  [[ -z "$(ls -A "${TMPDIR}")" ]]
}

@test "a missing source database fails instead of archiving an empty one" {
  rm "${SOURCE}/freenas-v1.db"

  run backup

  [[ ${status} -ne 0 ]]
  [[ -z "$(ls -A "${DEST}")" ]]
}
