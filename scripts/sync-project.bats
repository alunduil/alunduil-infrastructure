#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Unit tests for classify, the pure rule engine in sync-project.sh.
# Network-touching code paths are not exercised — they're covered by
# running the script against the live Inbox project, which alunduil
# performs out-of-band.

# shellcheck disable=SC2034 # these globals are read by the sourced helpers
setup() {
  FILED_BY_FIELD_NAME='Filed by'
  STATUS_FIELD_NAME='Status'
  # shellcheck source=sync-project.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/sync-project.sh"
}

# Item node wrapping a content object; repository and author defaults make
# an open item by someone else in an owned repo.
item() {
  jq -nc --argjson c "$1" --argjson fv "${2:-[]}" '{
    id: "i1",
    content: ({state: "OPEN", author: {login: "someone"},
               repository: {isArchived: false, owner: {login: "me"}}} + $c),
    fieldValues: {nodes: $fv}
  }'
}

ISSUE=https://github.com/me/r/issues/1
PR=https://github.com/me/r/pull/2

issue() { item "$(jq -c --arg url "$ISSUE" '{__typename: "Issue", url: $url} + .' <<<"${1:-{\}}")" "${2:-[]}"; }
pr() { item "$(jq -c --arg url "$PR" '{__typename: "PullRequest", url: $url} + .' <<<"${1:-{\}}")" "${2:-[]}"; }

# Issue content linking the PR at URL $1 (default $PR), authored by $2.
linked_pr() {
  jq -nc --arg url "${1:-$PR}" --arg author "$2" \
    '{closedByPullRequestsReferences: {nodes: [{url: $url, author: {login: $author}}]}}'
}

# Rows classify emits for the given item nodes, with "me" owning repos under "me".
rows() {
  printf '%s\n' "$@" | jq -s . | classify me '["me"]'
}

# Column classify picks for the item with the given URL.
column_of() {
  local url=$1
  shift
  rows "$@" | awk -F $'\x1f' -v url="$url" '$2 == url { print $6 }'
}

@test "archived repo items are removed" {
  run column_of "$ISSUE" "$(issue '{"repository": {"isArchived": true, "owner": {"login": "me"}}}')"
  [[ $output == REMOVE ]]
}

@test "closed issues and merged PRs are Closed" {
  [[ $(column_of "$ISSUE" "$(issue '{"state": "CLOSED"}')") == Closed ]]
  [[ $(column_of "$PR" "$(pr '{"state": "MERGED"}')") == Closed ]]
}

@test "an issue with an open blocker is Blocked, even with my open PR" {
  run column_of "$ISSUE" \
    "$(issue "$(linked_pr "" me | jq -c '. + {issueDependenciesSummary: {blockedBy: 1}}')")" \
    "$(pr '{"author": {"login": "me"}, "isDraft": true}')"
  [[ $output == Blocked ]]
}

@test "an issue moves with the open PR I authored" {
  run column_of "$ISSUE" \
    "$(issue "$(linked_pr "" me)")" \
    "$(pr '{"author": {"login": "me"}, "isDraft": true}')"
  [[ $output == "In progress" ]]
}

@test "an issue ignores a linked PR someone else authored" {
  run column_of "$ISSUE" \
    "$(issue "$(linked_pr "" someone)")" \
    "$(pr)"
  [[ $output == Backlog ]]
}

@test "an issue whose linked PR isn't on the board stays in Backlog" {
  run column_of "$ISSUE" \
    "$(issue "$(linked_pr https://github.com/me/r/pull/9 me)")"
  [[ $output == Backlog ]]
}

@test "my draft PR is In progress" {
  run column_of "$PR" "$(pr '{"author": {"login": "me"}, "isDraft": true}')"
  [[ $output == "In progress" ]]
}

@test "my PR with changes requested, failing CI, or a conflict is In progress" {
  [[ $(column_of "$PR" "$(pr '{"author": {"login": "me"}, "reviewDecision": "CHANGES_REQUESTED"}')") == "In progress" ]]
  [[ $(column_of "$PR" "$(pr '{"author": {"login": "me"}, "statusCheckRollup": {"state": "FAILURE"}}')") == "In progress" ]]
  [[ $(column_of "$PR" "$(pr '{"author": {"login": "me"}, "mergeable": "CONFLICTING"}')") == "In progress" ]]
}

@test "my green PR in a repo I don't own is Waiting on others" {
  run column_of "$PR" "$(pr '{"author": {"login": "me"}, "repository": {"isArchived": false, "owner": {"login": "upstream"}}}')"
  [[ $output == "Waiting on others" ]]
}

@test "my green PR in an owned repo Needs me" {
  run column_of "$PR" "$(pr '{"author": {"login": "me"}, "statusCheckRollup": {"state": "SUCCESS"}, "mergeable": "MERGEABLE"}')"
  [[ $output == "Needs me" ]]
}

@test "a PR I requested changes on waits until it re-requests me" {
  local reviewed='"latestOpinionatedReviews": {"nodes": [{"state": "CHANGES_REQUESTED", "author": {"login": "me"}}]}'
  [[ $(column_of "$PR" "$(pr "{${reviewed}}")") == "Waiting on others" ]]
  [[ $(column_of "$PR" "$(pr "{${reviewed}, \"reviewRequests\": {\"nodes\": [{\"requestedReviewer\": {\"login\": \"me\"}}]}}")") == "Needs me" ]]
}

@test "someone else's open PR Needs me" {
  run column_of "$PR" "$(pr)"
  [[ $output == "Needs me" ]]
}

@test "classify reads current field values and keeps empty ones in place" {
  run rows "$(issue '{}' '[{"name": "Needs me", "field": {"name": "Status"}}, {"text": "x", "field": {"name": "Title"}}]')"
  IFS=$'\x1f' read -r id url filed want_filed status want_status <<<"$output"
  [[ $id == i1 && $url == "$ISSUE" && -z $filed && $want_filed == someone ]]
  [[ $status == "Needs me" && $want_status == Backlog ]]
}

@test "classify keeps the search spelling of bot logins in filed by" {
  run rows "$(pr '{"author": {"__typename": "Bot", "login": "renovate"}}')"
  IFS=$'\x1f' read -r _ _ _ want_filed _ _ <<<"$output"
  [[ $want_filed == 'renovate[bot]' ]]
}

@test "classify skips items without a content url (draft items)" {
  run rows '{"id": "d1", "content": {}, "fieldValues": {"nodes": []}}'
  [[ -z $output ]]
}
