#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Tests for truenas-config-backup.sh. Every function touches the filesystem, so
# the script runs as a subprocess against a substituted source directory rather
# than being sourced for unit tests. The Cloud Sync task that invokes it and the
# transfer that follows are not exercised here.

# Restated rather than read from the script: an expectation derived from the
# code under test asserts nothing about it.
ARCHIVE_PREFIX='truenas-config-'
EXPIRED_ARCHIVE="${ARCHIVE_PREFIX}2000-01-01-000000.tar"

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

# Emits nothing when the glob is ambiguous, so a test that plants an archive and
# then asks for "the" archive fails on the reason rather than on a tar error.
archive_path() {
  local -a archives=("${DEST}/${ARCHIVE_PREFIX}"*.tar)

  if [[ ${#archives[@]} -ne 1 ]]; then
    printf 'expected one archive, found %d\n' "${#archives[@]}" >&2
    return 1
  fi

  printf '%s' "${archives[0]}"
}

extract() {
  tar -xf "$(archive_path)" -C "${BATS_TEST_TMPDIR}"
}

aged_file() {
  touch -d "${2}" "${DEST}/${1}"
}

# --- archive contents -----------------------------------------------------

@test "archive carries the database and the seed" {
  backup

  run tar -tf "$(archive_path)"
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
  aged_file "${EXPIRED_ARCHIVE}" '100 days ago'

  backup

  [[ ! -e "${DEST}/${EXPIRED_ARCHIVE}" ]]
}

@test "keeps archives inside the retention window" {
  aged_file "${EXPIRED_ARCHIVE}" '10 days ago'

  backup

  [[ -e "${DEST}/${EXPIRED_ARCHIVE}" ]]
}

@test "retention window is configurable" {
  aged_file "${EXPIRED_ARCHIVE}" '10 days ago'

  backup 5

  [[ ! -e "${DEST}/${EXPIRED_ARCHIVE}" ]]
}

@test "prune is scoped to the archive prefix" {
  aged_file 'other-config-2000-01-01-000000.tar' '100 days ago'
  aged_file 'backup.sh' '100 days ago'

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
