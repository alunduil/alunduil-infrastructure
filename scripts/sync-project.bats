#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the pure helpers in sync-project.sh (desired_status,
# parse_items). Network-touching code paths are not exercised — they're
# covered by running the script against the live Inbox project, which
# alunduil performs out-of-band.

# shellcheck disable=SC2034 # these globals are read by the sourced helpers
setup() {
  # parse_items keys field values by these names; desired_status maps the
  # item type to these option ids/names. Set before any helper is called.
  FILED_BY_FIELD_NAME='Filed by'
  STATUS_FIELD_NAME='Status'
  PR_STATUS_OPTION_ID='rev0'
  PR_STATUS_NAME='Review'
  ISSUE_STATUS_OPTION_ID='bak0'
  ISSUE_STATUS_NAME='Backlog'
  # shellcheck source=sync-project.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/sync-project.sh"
}

# --- desired_status -------------------------------------------------------

@test "desired_status routes a pull-request url to pr_status" {
  run desired_status "https://github.com/o/r/pull/7"
  [[ $output == $'rev0\tReview' ]]
}

@test "desired_status routes an issue url to issue_status" {
  run desired_status "https://github.com/o/r/issues/7"
  [[ $output == $'bak0\tBacklog' ]]
}

@test "desired_status keys on the /pull/ path segment, not the substring" {
  # A repo whose name contains 'pull' must not be mistaken for a PR.
  run desired_status "https://github.com/o/pull-mirror/issues/7"
  [[ $output == $'bak0\tBacklog' ]]
}

@test "desired_status is newline-terminated so the per-item read returns 0" {
  # Regression: desired_status emitted no trailing newline, so the reconcile
  # loop's `read` hit EOF and returned 1, aborting the script under set -e on
  # the first item. The read must succeed and populate both fields.
  rc=0
  IFS=$'\t' read -r id name < <(desired_status "https://github.com/o/r/issues/9") || rc=$?
  [[ $rc -eq 0 ]]
  [[ $id == bak0 && $name == Backlog ]]
}

# --- parse_items ----------------------------------------------------------

# Minimal shape of a `node(id:){ items{ nodes } }` GraphQL response.
items_response() {
  printf '{"data":{"node":{"items":{"nodes":[%s]}}}}' "$1"
}

@test "parse_items emits url, filed-by, status, and id" {
  json=$(items_response '
    {"id":"i1","content":{"url":"https://github.com/o/r/pull/1"},
     "fieldValues":{"nodes":[
       {"text":"alunduil","field":{"name":"Filed by"}},
       {"name":"Review","field":{"name":"Status"}}]}}')
  run parse_items <<<"$json"
  [[ $output == $'https://github.com/o/r/pull/1\talunduil\tReview\ti1' ]]
}

@test "parse_items defaults a missing status to empty" {
  json=$(items_response '
    {"id":"i2","content":{"url":"https://github.com/o/r/issues/2"},
     "fieldValues":{"nodes":[
       {"text":"alunduil","field":{"name":"Filed by"}}]}}')
  run parse_items <<<"$json"
  [[ $output == $'https://github.com/o/r/issues/2\talunduil\t\ti2' ]]
}

@test "parse_items defaults a missing filed-by to empty" {
  json=$(items_response '
    {"id":"i3","content":{"url":"https://github.com/o/r/issues/3"},
     "fieldValues":{"nodes":[
       {"name":"Backlog","field":{"name":"Status"}}]}}')
  run parse_items <<<"$json"
  [[ $output == $'https://github.com/o/r/issues/3\t\tBacklog\ti3' ]]
}

@test "parse_items skips items without a content url (draft items)" {
  json=$(items_response '
    {"id":"i4","content":{},"fieldValues":{"nodes":[]}},
    {"id":"i5","content":{"url":"https://github.com/o/r/issues/5"},
     "fieldValues":{"nodes":[]}}')
  run parse_items <<<"$json"
  [[ $output == $'https://github.com/o/r/issues/5\t\t\ti5' ]]
}

@test "parse_items ignores field values from other fields" {
  json=$(items_response '
    {"id":"i6","content":{"url":"https://github.com/o/r/pull/6"},
     "fieldValues":{"nodes":[
       {"text":"Some Title","field":{"name":"Title"}},
       {"text":"alunduil","field":{"name":"Filed by"}},
       {"name":"Review","field":{"name":"Status"}}]}}')
  run parse_items <<<"$json"
  [[ $output == $'https://github.com/o/r/pull/6\talunduil\tReview\ti6' ]]
}
