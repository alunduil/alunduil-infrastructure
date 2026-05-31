#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for the pure helpers in bootstrap.sh
# (to_key, converge_options, options_equal). Network-touching code paths
# are not exercised — they're covered by running the script against the
# live Inbox project, which alunduil performs out-of-band.

setup() {
  # shellcheck source=bootstrap.sh
  source "${BATS_TEST_DIRNAME}/bootstrap.sh"
}

# --- to_key ---------------------------------------------------------------

@test "to_key uppercases a plain word" {
  [[ "$(to_key Status)" == "STATUS" ]]
}

@test "to_key replaces space with underscore" {
  [[ "$(to_key 'Filed by')" == "FILED_BY" ]]
}

@test "to_key collapses non-alnum runs to underscores" {
  [[ "$(to_key 'sub-issues/progress')" == "SUB_ISSUES_PROGRESS" ]]
}

@test "to_key strips trailing underscores" {
  [[ "$(to_key 'trailing!!')" == "TRAILING" ]]
}

@test "to_key keeps digits" {
  [[ "$(to_key 'q1 2026')" == "Q1_2026" ]]
}

# --- converge_options -----------------------------------------------------

@test "converge_options on empty current produces options without ids" {
  current='[]'
  spec='[{"name":"Backlog","color":"GRAY"}]'
  result=$(converge_options "$current" "$spec")
  [[ $result == '[{"name":"Backlog","color":"GRAY","description":""}]' ]]
}

@test "converge_options matches by id and preserves it" {
  current='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]'
  spec='[{"id":"abcd1234","name":"Backlog","color":"GRAY"}]'
  result=$(converge_options "$current" "$spec")
  [[ $result == '[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]' ]]
}

@test "converge_options recovers a UI rename via id match" {
  current='[{"id":"abcd1234","name":"Renamed","color":"GRAY","description":""}]'
  spec='[{"id":"abcd1234","name":"Backlog","color":"GRAY"}]'
  result=$(converge_options "$current" "$spec")
  [[ $result == '[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]' ]]
}

@test "converge_options falls back to name match when id is absent in current" {
  current='[{"id":"freshid0","name":"Backlog","color":"GRAY","description":""}]'
  spec='[{"id":"abcd1234","name":"Backlog","color":"GRAY"}]'
  result=$(converge_options "$current" "$spec")
  [[ $result == '[{"id":"freshid0","name":"Backlog","color":"GRAY","description":""}]' ]]
}

@test "converge_options uses spec color over current color (drift correction)" {
  current='[{"id":"abcd1234","name":"Backlog","color":"BLUE","description":""}]'
  spec='[{"id":"abcd1234","name":"Backlog","color":"GRAY"}]'
  result=$(converge_options "$current" "$spec")
  [[ $result == '[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]' ]]
}

@test "converge_options emits a new option with no id when neither id nor name matches" {
  current='[{"id":"abcd1234","name":"Old","color":"GRAY","description":""}]'
  spec='[{"id":"abcd1234","name":"Old","color":"GRAY"},{"name":"Brand New","color":"BLUE"}]'
  result=$(converge_options "$current" "$spec")
  expected='[{"id":"abcd1234","name":"Old","color":"GRAY","description":""},{"name":"Brand New","color":"BLUE","description":""}]'
  [[ $result == "$expected" ]]
}

@test "converge_options uses spec description, overwriting current's" {
  current='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":"old text"}]'
  spec='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":"new text"}]'
  result=$(converge_options "$current" "$spec")
  [[ $result == '[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":"new text"}]' ]]
}

@test "converge_options defaults description to empty when spec omits it" {
  current='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":"old"}]'
  spec='[{"id":"abcd1234","name":"Backlog","color":"GRAY"}]'
  result=$(converge_options "$current" "$spec")
  [[ $result == '[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]' ]]
}

# --- options_equal --------------------------------------------------------

@test "options_equal returns true for identical option arrays" {
  a='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]'
  b='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]'
  options_equal "$a" "$b"
}

@test "options_equal ignores key ordering" {
  a='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]'
  b='[{"description":"","color":"GRAY","name":"Backlog","id":"abcd1234"}]'
  options_equal "$a" "$b"
}

@test "options_equal projects current to managed fields only" {
  a='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":"","__typename":"ignored"}]'
  b='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]'
  options_equal "$a" "$b"
}

@test "options_equal returns false when colors differ" {
  a='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]'
  b='[{"id":"abcd1234","name":"Backlog","color":"BLUE","description":""}]'
  run options_equal "$a" "$b"
  [[ $status -ne 0 ]]
}

@test "options_equal returns false when lengths differ" {
  a='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]'
  b='[]'
  run options_equal "$a" "$b"
  [[ $status -ne 0 ]]
}

@test "options_equal treats missing id in desired as null for comparison" {
  a='[{"id":"abcd1234","name":"Backlog","color":"GRAY","description":""}]'
  b='[{"name":"Backlog","color":"GRAY","description":""}]'
  run options_equal "$a" "$b"
  [[ $status -ne 0 ]]
}
