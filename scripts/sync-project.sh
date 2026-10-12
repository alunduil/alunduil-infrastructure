#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Mirror open issues/PRs from a set of GitHub search queries onto a
# Projects v2 board, populating a configured text field with the author
# login and a single-select Status by whose move it is. Reads a JSON spec
# from github/projects/<board>.json:
#
#   {
#     "owner": "alunduil",
#     "title": "Inbox",
#     "login": "alunduil",
#     "filed_by_field": "Filed by",
#     "status_field": "Status",
#     "sources": [
#       { "type": "owner", "logins": [...] },
#       { "type": "author", "login": "..." },
#       { "type": "assignee", "login": "..." }
#     ]
#   }
#
# `login` is the person the board answers "whose move is it?" for; the
# owner-source logins are the repos they merge in. The rules live in
# classify below and route to the option names in STATUSES, which the
# status field must declare. The script is authoritative: every run
# recomputes Status for every board item, so hand moves don't stick.
# Items from archived repos are removed from the board.
#
# Runs hourly from CI; safe to invoke locally — falls back to ambient
# `gh` auth when GH_PROJECT_SYNC_TOKEN is unset. The scheduled job can't be
# reproduced from a PR (the project-sync secret isn't exposed there), so in
# CI it traces every command and an ERR trap names the failing line; see the
# verbosity block past the source guard. Local runs stay quiet unless
# SYNC_DEBUG is set.
#
# Steady-state cost: two paginated reads of the board node (a lean URL read
# to find additions, then an enriched read the rules run over) plus one
# search per source-leg. Mutations fire only for new URLs, stale field
# values, and archived-repo items.
#
# Reads go through hand-written GraphQL rather than `gh project
# field-list`/`item-list`: the porcelain over-fetches every field of every
# item (~100 GraphQL points per field-list, ~1 per item), and there is no
# flag to trim it. The lean queries below cost 1–2 points per 100-item page.

# -E (errtrace) propagates the ERR trap set in the executable body into the
# helper functions and the search subshells so a failure anywhere is located.
set -Eeuo pipefail

STATUSES=("Blocked" "In progress" "Needs me" "Waiting on others" "Backlog" "Closed")

# Read a JSON array of board items (enriched query shape) on stdin and emit
# one row per item with a content URL, fields separated by the ASCII unit
# separator (0x1f). A tab separator would break the consuming `read`, which
# collapses runs of whitespace separators and so drops empty fields:
#
#   item-id  url  filed  want-filed  status  want-status
#
# want-status is REMOVE for an item whose repo is archived. Rules, first
# match wins ("me" is $me, "owned" means an owner in $owned):
#
#   1. Closed: the issue is closed, or the PR is closed or merged.
#   2. Blocked: an issue with an open blocked-by dependency. GitHub has no
#      dependencies on PRs.
#   3. An issue with an open linked PR I authored takes that PR's column.
#   4. In progress: my draft PR, or my PR with changes requested, failing
#      CI, or a merge conflict.
#   5. Waiting on others: my PR in a repo I don't own, or a PR whose latest
#      review from me requests changes and that hasn't re-requested me.
#   6. Needs me: any other open PR.
#   7. Backlog: any other open issue.
#
# An issue's linked PR is looked up among the board's PRs, so a linked PR
# that isn't on the board leaves the issue on the rules below rule 3.
classify() {
  jq -r --arg me "$1" --argjson owned "$2" \
    --arg filed "${FILED_BY_FIELD_NAME}" --arg status "${STATUS_FIELD_NAME}" '
    def mine: .author.login == $me;
    def owned: .repository.owner.login as $o | $owned | index($o) != null;
    def my_review: [.latestOpinionatedReviews.nodes[]? | select(.author.login == $me) | .state] | first;
    def rerequested: [.reviewRequests.nodes[]?.requestedReviewer.login] | index($me) != null;
    def needs_my_work:
      .isDraft
      or .reviewDecision == "CHANGES_REQUESTED"
      or (.statusCheckRollup.state | IN("FAILURE", "ERROR"))
      or .mergeable == "CONFLICTING";
    def awaiting_author: my_review == "CHANGES_REQUESTED" and (rerequested | not);
    def pr_column:
      if mine and needs_my_work then "In progress"
      elif (mine and (owned | not)) or awaiting_author then "Waiting on others"
      else "Needs me"
      end;
    def column($prs):
      if .repository.isArchived then "REMOVE"
      elif .state != "OPEN" then "Closed"
      elif .__typename == "PullRequest" then pr_column
      elif .issueDependenciesSummary.blockedBy > 0 then "Blocked"
      else [.closedByPullRequestsReferences.nodes[]? | select(mine) | $prs[.url] // empty] | first // "Backlog"
      end;
    # Search spells bot logins "name[bot]"; GraphQL drops the suffix. Keep
    # the search spelling the board already holds.
    def filed_by: if .author.__typename == "Bot" then .author.login + "[bot]" else .author.login // "unknown" end;
    def value($field; $key): [.fieldValues.nodes[]? | select(.field.name == $field) | .[$key]] | first // "";

    map(select(.content.url)) as $items
    | ($items
       | map(.content | select(.__typename == "PullRequest" and .state == "OPEN") | {key: .url, value: pr_column})
       | from_entries) as $prs
    | $items[]
    | [ .id,
        .content.url,
        value($filed; "text"),
        (.content | filed_by),
        value($status; "name"),
        (.content | column($prs)) ]
    | join("\u001f")'
}

# Page through the board node, running the query in $1 with the cursor, and
# emit each item node as one compact JSON line.
board_pages() {
  local query=$1 cursor="" resp
  while :; do
    resp=$(gh api graphql -F id="${PROJECT_ID}" -F cursor="${cursor}" -f query="${query}")
    jq -c '.data.node.items.nodes[]' <<<"${resp}"
    [[ $(jq -r '.data.node.items.pageInfo.hasNextPage' <<<"${resp}") == true ]] || break
    cursor=$(jq -r '.data.node.items.pageInfo.endCursor' <<<"${resp}")
  done
}

# shellcheck disable=SC2016 # $id/$cursor are GraphQL variables, not shell
BOARD_URLS_QUERY='
  query($id: ID!, $cursor: String) {
    node(id: $id) {
      ... on ProjectV2 {
        items(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes { content { ... on Issue { url } ... on PullRequest { url } } }
        }
      }
    }
  }'

# Everything classify reads. latestOpinionatedReviews holds one review per
# reviewer, so first: 20 covers any realistic reviewer count.
# shellcheck disable=SC2016 # $id/$cursor are GraphQL variables, not shell
BOARD_ITEMS_QUERY='
  query($id: ID!, $cursor: String) {
    node(id: $id) {
      ... on ProjectV2 {
        items(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            content {
              __typename
              ... on Issue {
                url state author { __typename login }
                repository { isArchived owner { login } }
                issueDependenciesSummary { blockedBy }
                closedByPullRequestsReferences(first: 5, includeClosedPrs: false) {
                  nodes { url author { login } }
                }
              }
              ... on PullRequest {
                url state isDraft author { __typename login }
                repository { isArchived owner { login } }
                reviewDecision mergeable
                statusCheckRollup { state }
                reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login } } } }
                latestOpinionatedReviews(first: 20) { nodes { state author { login } } }
              }
            }
            fieldValues(first: 8) {
              nodes {
                ... on ProjectV2ItemFieldTextValue { text field { ... on ProjectV2FieldCommon { name } } }
                ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2FieldCommon { name } } }
              }
            }
          }
        }
      }
    }
  }'

# Set one field on a board item: edit_item <item-id> <field-id> <value-flag> <value>.
edit_item() {
  gh project item-edit --project-id "${PROJECT_ID}" \
    --id "$1" --field-id "$2" "$3" "$4" >/dev/null
}

# Emit one gh-search argument string per source-leg. Two legs per source
# (issues + prs). The trailing word-split on $leg in the consumer is
# intentional; arguments are jq-controlled, not user input.
search_legs() {
  jq -r '
    .sources[] |
    if .type == "owner" then
      ([.logins[] | "--owner=" + .] | join(" ")) as $owners |
      "issues " + $owners,
      "prs " + $owners
    elif .type == "author" then
      "issues --author=" + .login,
      "prs --author=" + .login
    elif .type == "assignee" then
      "issues --assignee=" + .login,
      "prs --assignee=" + .login
    else
      error("unknown source type: " + .type)
    end
  ' "${SPEC}"
}

# Skip the executable body when sourced (e.g. by sync-project.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # shellcheck disable=SC2317 # reached only when sourced, which shellcheck can't see
  return 0 2>/dev/null || true
fi

# CI troubleshooting verbosity. The ERR trap turns a silent `exit 1` into a
# located, named failure (it disables xtrace first so its own echo isn't
# traced). xtrace then shows every gh/jq call. Single-quoted trap body so
# $LINENO/$BASH_COMMAND expand when it fires, not when it's installed.
# shellcheck disable=SC2154 # rc is assigned (rc=$?) at the top of the trap body
trap 'rc=$?; { set +x; } 2>/dev/null; echo "sync-project: failed (exit ${rc}) at ${BASH_SOURCE##*/}:${LINENO}: ${BASH_COMMAND}" >&2' ERR

want_xtrace=""
if [[ -n ${CI:-} || -n ${SYNC_DEBUG:-} ]]; then
  want_xtrace=1
  PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '
  set -x
fi

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <spec.json>" >&2
  exit 64
fi

SPEC=$1
[[ -r ${SPEC} ]] || {
  echo "error: cannot read spec '${SPEC}'" >&2
  exit 1
}

PROJECT_OWNER=$(jq -r '.owner' "${SPEC}")
PROJECT_TITLE=$(jq -r '.title' "${SPEC}")
LOGIN=$(jq -r '.login // empty' "${SPEC}")
OWNED_LOGINS=$(jq -c '[.sources[] | select(.type == "owner") | .logins[]]' "${SPEC}")
FILED_BY_FIELD_NAME=$(jq -r '.filed_by_field' "${SPEC}")
STATUS_FIELD_NAME=$(jq -r '.status_field // empty' "${SPEC}")
SEARCH_LIMIT=1000

if [[ -z ${LOGIN} || -z ${STATUS_FIELD_NAME} ]]; then
  echo "spec '${SPEC}' needs both login and status_field" >&2
  exit 1
fi

if [[ -n ${GH_PROJECT_SYNC_TOKEN:-} ]]; then
  # Assign with xtrace off so the token never lands in the trace stream.
  # (Actions also masks the secret, but don't rely on masking alone.)
  { set +x; } 2>/dev/null
  export GH_TOKEN=${GH_PROJECT_SYNC_TOKEN}
  if [[ -n ${want_xtrace} ]]; then set -x; fi
fi

# Resolve the project by title so disaster-recovery (board recreation)
# doesn't strand this script on a hard-coded number.
project_match=$(
  gh project list --owner "${PROJECT_OWNER}" --limit 100 --format json \
    --jq ".projects | map(select(.title == \"${PROJECT_TITLE}\"))"
)
if [[ $(jq 'length' <<<"${project_match}") -ne 1 ]]; then
  echo "expected exactly one project titled '${PROJECT_TITLE}' under @${PROJECT_OWNER}" >&2
  exit 1
fi
PROJECT_ID=$(jq -r '.[0].id' <<<"${project_match}")
PROJECT_NUMBER=$(jq -r '.[0].number' <<<"${project_match}")

# Field IDs (and single-select option IDs) come from one lean GraphQL
# query on the opaque project node ID, which works whether the owner is a
# user or an org. Resolved once here; the item loop is then a pure lookup.
fields_json=$(
  # shellcheck disable=SC2016 # $id is a GraphQL variable, not shell
  gh api graphql -F id="${PROJECT_ID}" --jq '.data.node.fields.nodes' -f query='
    query($id: ID!) {
      node(id: $id) {
        ... on ProjectV2 {
          fields(first: 50) {
            nodes {
              __typename
              ... on ProjectV2FieldCommon { id name }
              ... on ProjectV2SingleSelectField { id name options { id name } }
            }
          }
        }
      }
    }'
)

FILED_BY_FIELD_ID=$(jq -r --arg n "${FILED_BY_FIELD_NAME}" \
  'map(select(.name == $n))[0].id // empty' <<<"${fields_json}")
if [[ -z ${FILED_BY_FIELD_ID} ]]; then
  echo "no field named '${FILED_BY_FIELD_NAME}' on project '${PROJECT_TITLE}'" >&2
  exit 1
fi

status_field_json=$(jq --arg n "${STATUS_FIELD_NAME}" \
  'map(select(.name == $n))[0]' <<<"${fields_json}")
STATUS_FIELD_ID=$(jq -r '.id // empty' <<<"${status_field_json}")
if [[ -z ${STATUS_FIELD_ID} ]]; then
  echo "no field named '${STATUS_FIELD_NAME}' on project '${PROJECT_TITLE}'" >&2
  exit 1
fi
declare -A status_option_id
for name in "${STATUSES[@]}"; do
  status_option_id[$name]=$(jq -r --arg n "${name}" \
    '.options[] | select(.name == $n) | .id' <<<"${status_field_json}")
  if [[ -z ${status_option_id[$name]} ]]; then
    echo "field '${STATUS_FIELD_NAME}' is missing option '${name}'" >&2
    exit 1
  fi
done

declare -A on_board
while IFS= read -r url; do
  [[ -n $url ]] && on_board[$url]=1
done < <(board_pages "${BOARD_URLS_QUERY}" | jq -r '.content.url // empty')

added=0
updated=0
removed=0
skipped=0

while IFS= read -r url; do
  [[ -n ${on_board[$url]:-} ]] && continue
  printf 'adding %s\n' "$url"
  gh project item-add "${PROJECT_NUMBER}" \
    --owner "${PROJECT_OWNER}" --url "$url" >/dev/null
  added=$((added + 1))
done < <(
  while IFS= read -r leg; do
    # shellcheck disable=SC2086 # $leg holds jq-controlled gh-search arguments
    gh search ${leg} --state=open --archived=false \
      --limit "${SEARCH_LIMIT}" --json url --jq '.[].url'
  done < <(search_legs) | sort -u
)

while IFS=$'\x1f' read -r item_id url filed want_filed status want_status; do
  if [[ $want_status == REMOVE ]]; then
    printf 'removing %s (archived repo)\n' "$url"
    gh project item-delete "${PROJECT_NUMBER}" \
      --owner "${PROJECT_OWNER}" --id "$item_id" >/dev/null
    removed=$((removed + 1))
    continue
  fi

  changed=0
  if [[ $filed != "$want_filed" ]]; then
    printf 'updating filed by on %s (%s -> %s)\n' \
      "$url" "${filed:-<none>}" "$want_filed"
    edit_item "$item_id" "${FILED_BY_FIELD_ID}" --text "$want_filed"
    changed=1
  fi
  if [[ $status != "$want_status" ]]; then
    printf 'updating status on %s (%s -> %s)\n' \
      "$url" "${status:-<none>}" "$want_status"
    edit_item "$item_id" "${STATUS_FIELD_ID}" \
      --single-select-option-id "${status_option_id[$want_status]}"
    changed=1
  fi
  if [[ $changed -eq 1 ]]; then
    updated=$((updated + 1))
  else
    skipped=$((skipped + 1))
  fi
done < <(board_pages "${BOARD_ITEMS_QUERY}" | jq -s . | classify "${LOGIN}" "${OWNED_LOGINS}")

printf 'done: added=%d updated=%d removed=%d skipped=%d\n' \
  "$added" "$updated" "$removed" "$skipped"
