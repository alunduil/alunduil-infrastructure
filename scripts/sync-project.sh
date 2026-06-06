#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Mirror open issues/PRs from a set of GitHub search queries onto a
# Projects v2 board, populating a configured text field with the author
# login and a single-select Status by item type. Reads a JSON spec from
# github/projects/<board>.json:
#
#   {
#     "owner": "alunduil",
#     "title": "Inbox",
#     "filed_by_field": "Filed by",
#     "status_field": "Status",
#     "pr_status": "Review",
#     "issue_status": "Backlog",
#     "sources": [
#       { "type": "owner", "logins": [...] },
#       { "type": "author", "login": "..." },
#       { "type": "assignee", "login": "..." }
#     ]
#   }
#
# Status handling is opt-in: omit status_field to leave Status untouched.
# When set, the script is authoritative — open PRs are forced to pr_status
# and open issues to issue_status on every run, so it self-heals drift
# rather than deferring to GitHub's built-in "item added" workflow (which
# can't tell a PR from an issue and so lands everything in one column).
#
# Runs hourly from CI; safe to invoke locally — falls back to ambient
# `gh` auth when GH_PROJECT_SYNC_TOKEN is unset.
#
# Steady-state cost: a paginated read of the board node plus one search
# per source-leg. Mutations (item-add, item-edit) fire only for new URLs,
# stale filed-by values, or items whose Status doesn't match their type.
#
# Reads go through hand-written GraphQL rather than `gh project
# field-list`/`item-list`: the porcelain over-fetches every field of every
# item (~100 GraphQL points per field-list, ~1 per item), and there is no
# flag to trim it. The lean queries below cost ~1 point per 100-item page.

set -euo pipefail

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
FILED_BY_FIELD_NAME=$(jq -r '.filed_by_field' "${SPEC}")
STATUS_FIELD_NAME=$(jq -r '.status_field // empty' "${SPEC}")
SEARCH_LIMIT=1000

if [[ -n ${GH_PROJECT_SYNC_TOKEN:-} ]]; then
  export GH_TOKEN=${GH_PROJECT_SYNC_TOKEN}
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

# Status sync is opt-in. When status_field is set, resolve the field and
# the per-type option IDs up front so the item loop is a pure ID lookup.
if [[ -n ${STATUS_FIELD_NAME} ]]; then
  PR_STATUS_NAME=$(jq -r '.pr_status // empty' "${SPEC}")
  ISSUE_STATUS_NAME=$(jq -r '.issue_status // empty' "${SPEC}")
  if [[ -z ${PR_STATUS_NAME} || -z ${ISSUE_STATUS_NAME} ]]; then
    echo "status_field '${STATUS_FIELD_NAME}' requires both pr_status and issue_status" >&2
    exit 1
  fi

  status_field_json=$(jq --arg n "${STATUS_FIELD_NAME}" \
    'map(select(.name == $n))[0]' <<<"${fields_json}")
  STATUS_FIELD_ID=$(jq -r '.id // empty' <<<"${status_field_json}")
  if [[ -z ${STATUS_FIELD_ID} ]]; then
    echo "no field named '${STATUS_FIELD_NAME}' on project '${PROJECT_TITLE}'" >&2
    exit 1
  fi
  PR_STATUS_OPTION_ID=$(jq -r --arg n "${PR_STATUS_NAME}" '.options[] | select(.name == $n) | .id' <<<"${status_field_json}")
  ISSUE_STATUS_OPTION_ID=$(jq -r --arg n "${ISSUE_STATUS_NAME}" '.options[] | select(.name == $n) | .id' <<<"${status_field_json}")
  if [[ -z ${PR_STATUS_OPTION_ID} || -z ${ISSUE_STATUS_OPTION_ID} ]]; then
    echo "field '${STATUS_FIELD_NAME}' is missing option '${PR_STATUS_NAME}' or '${ISSUE_STATUS_NAME}'" >&2
    exit 1
  fi
fi

# Emit the desired Status option id + name for a URL: PRs (/pull/) take
# pr_status, everything else issue_status. Tab-separated for `read`.
desired_status() {
  if [[ $1 == */pull/* ]]; then
    printf '%s\t%s' "${PR_STATUS_OPTION_ID}" "${PR_STATUS_NAME}"
  else
    printf '%s\t%s' "${ISSUE_STATUS_OPTION_ID}" "${ISSUE_STATUS_NAME}"
  fi
}

# Mirror the board as url<TAB>filed<TAB>status<TAB>item-id, paginating the
# project node and pulling only the two field values we act on. An item
# with no value for a field simply omits it, hence the empty-string
# defaults (which also match the "" used in the comparisons below).
board_items() {
  local cursor="" resp
  while :; do
    # shellcheck disable=SC2016 # $id/$cursor are GraphQL variables, not shell
    resp=$(
      gh api graphql -F id="${PROJECT_ID}" -F cursor="${cursor}" -f query='
        query($id: ID!, $cursor: String) {
          node(id: $id) {
            ... on ProjectV2 {
              items(first: 100, after: $cursor) {
                pageInfo { hasNextPage endCursor }
                nodes {
                  id
                  content { ... on Issue { url } ... on PullRequest { url } }
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
    )
    jq -r --arg filed "${FILED_BY_FIELD_NAME}" --arg status "${STATUS_FIELD_NAME}" '
      .data.node.items.nodes[]
      | select(.content.url)
      | [ .content.url,
          ([.fieldValues.nodes[]? | select(.field.name == $filed) | .text] | first // ""),
          ([.fieldValues.nodes[]? | select(.field.name == $status) | .name] | first // ""),
          .id ]
      | @tsv
    ' <<<"${resp}"
    [[ $(jq -r '.data.node.items.pageInfo.hasNextPage' <<<"${resp}") == true ]] || break
    cursor=$(jq -r '.data.node.items.pageInfo.endCursor' <<<"${resp}")
  done
}

declare -A existing_id existing_filed existing_status
while IFS=$'\t' read -r url filed status item_id; do
  [[ -z $url ]] && continue
  existing_id[$url]=$item_id
  existing_filed[$url]=$filed
  existing_status[$url]=$status
done < <(board_items)

jq_pair='.[] | "\(.url)\t\(.author.login // "unknown")"'

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

added=0
updated=0
skipped=0

while IFS=$'\t' read -r url author; do
  if [[ -n ${STATUS_FIELD_NAME} ]]; then
    IFS=$'\t' read -r want_status_id want_status_name < <(desired_status "$url")
  fi

  if [[ -z ${existing_id[$url]:-} ]]; then
    printf 'adding %s (filed by %s)\n' "$url" "$author"
    item_id=$(
      gh project item-add "${PROJECT_NUMBER}" \
        --owner "${PROJECT_OWNER}" --url "$url" \
        --format json --jq '.id'
    )
    gh project item-edit \
      --project-id "${PROJECT_ID}" \
      --id "$item_id" \
      --field-id "${FILED_BY_FIELD_ID}" \
      --text "$author" >/dev/null
    if [[ -n ${STATUS_FIELD_NAME} ]]; then
      gh project item-edit \
        --project-id "${PROJECT_ID}" \
        --id "$item_id" \
        --field-id "${STATUS_FIELD_ID}" \
        --single-select-option-id "${want_status_id}" >/dev/null
    fi
    added=$((added + 1))
    continue
  fi

  changed=0
  if [[ ${existing_filed[$url]} != "$author" ]]; then
    printf 'updating filed by on %s (%s -> %s)\n' \
      "$url" "${existing_filed[$url]}" "$author"
    gh project item-edit \
      --project-id "${PROJECT_ID}" \
      --id "${existing_id[$url]}" \
      --field-id "${FILED_BY_FIELD_ID}" \
      --text "$author" >/dev/null
    changed=1
  fi
  if [[ -n ${STATUS_FIELD_NAME} && ${existing_status[$url]} != "$want_status_name" ]]; then
    printf 'updating status on %s (%s -> %s)\n' \
      "$url" "${existing_status[$url]:-<none>}" "$want_status_name"
    gh project item-edit \
      --project-id "${PROJECT_ID}" \
      --id "${existing_id[$url]}" \
      --field-id "${STATUS_FIELD_ID}" \
      --single-select-option-id "${want_status_id}" >/dev/null
    changed=1
  fi
  if [[ $changed -eq 1 ]]; then
    updated=$((updated + 1))
  else
    skipped=$((skipped + 1))
  fi
done < <(
  while IFS= read -r leg; do
    # shellcheck disable=SC2086 # $leg holds jq-controlled gh-search arguments
    gh search ${leg} --state=open --archived=false \
      --limit "${SEARCH_LIMIT}" --json url,author --jq "${jq_pair}"
  done < <(search_legs) | sort -u
)

printf 'done: added=%d updated=%d skipped=%d\n' "$added" "$updated" "$skipped"
