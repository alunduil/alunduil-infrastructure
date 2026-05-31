#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Mirror open issues/PRs from a set of GitHub search queries onto a
# Projects v2 board, populating a configured text field with the author
# login. Reads a JSON spec from scripts/sync-specs/<board>.json:
#
#   {
#     "owner": "alunduil",
#     "title": "Inbox",
#     "filed_by_field": "Filed by",
#     "sources": [
#       { "type": "owner", "logins": [...] },
#       { "type": "author", "login": "..." },
#       { "type": "assignee", "login": "..." }
#     ]
#   }
#
# Runs hourly from CI; safe to invoke locally — falls back to ambient
# `gh` auth when GH_PROJECT_SYNC_TOKEN is unset.
#
# Steady-state cost: one item-list + one search per source-leg. Mutations
# (item-add, item-edit) fire only for new URLs or stale filed-by values.

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
SEARCH_LIMIT=1000
# Comfortable headroom above the current ~520 items on the largest board.
PROJECT_LIMIT=5000

if [[ -n ${GH_PROJECT_SYNC_TOKEN:-} ]]; then
  export GH_TOKEN=${GH_PROJECT_SYNC_TOKEN}
fi

# Fail fast with an actionable message instead of letting the first `gh`
# call below die with an opaque exit 4. Catches the CI case (token unset
# or invalid on the project-sync environment) and a local run with no
# ambient `gh` auth.
if ! gh auth status >/dev/null 2>&1; then
  echo "error: no usable GitHub auth for the sync" >&2
  echo "  CI: set GH_PROJECT_SYNC_TOKEN on the project-sync environment" >&2
  echo "      (docs/how-to/create-github-project-sync-token.md)" >&2
  echo "  local: run 'gh auth login'" >&2
  exit 4
fi

# Resolve project and field IDs by title/name so disaster-recovery (board
# recreation) doesn't strand this script.
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

FILED_BY_FIELD_ID=$(
  gh project field-list "${PROJECT_NUMBER}" --owner "${PROJECT_OWNER}" \
    --format json \
    --jq ".fields | map(select(.name == \"${FILED_BY_FIELD_NAME}\"))[0].id"
)
if [[ -z ${FILED_BY_FIELD_ID} || ${FILED_BY_FIELD_ID} == null ]]; then
  echo "no field named '${FILED_BY_FIELD_NAME}' on project '${PROJECT_TITLE}'" >&2
  exit 1
fi

# `gh project item-list` lower-cases custom field names as JSON keys.
filed_by_key=${FILED_BY_FIELD_NAME,,}

declare -A existing_id existing_filed

while IFS=$'\t' read -r url filed item_id; do
  [[ -z $url ]] && continue
  existing_id[$url]=$item_id
  existing_filed[$url]=$filed
done < <(
  gh project item-list "${PROJECT_NUMBER}" --owner "${PROJECT_OWNER}" \
    --format json --limit "${PROJECT_LIMIT}" \
    --jq ".items[] | select(.content.url) | \"\\(.content.url)\\t\\(.[\"${filed_by_key}\"] // \"\")\\t\\(.id)\""
)

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
    added=$((added + 1))
  elif [[ ${existing_filed[$url]} != "$author" ]]; then
    printf 'updating filed by on %s (%s -> %s)\n' \
      "$url" "${existing_filed[$url]}" "$author"
    gh project item-edit \
      --project-id "${PROJECT_ID}" \
      --id "${existing_id[$url]}" \
      --field-id "${FILED_BY_FIELD_ID}" \
      --text "$author" >/dev/null
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
