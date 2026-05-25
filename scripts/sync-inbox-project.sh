#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Mirrors every open issue/PR from alunduil, dungeon-studio, and qua-world
# (plus anything authored by or assigned to alunduil anywhere) into
# Projects v2 #3 (Inbox), and sets the custom "Filed by" field to the
# author login. Runs hourly from CI; safe to invoke locally — falls back
# to ambient `gh` auth when INBOX_SYNC_TOKEN is unset.
#
# Steady-state cost: one item-list + six search calls. Mutations (item-add,
# item-edit) fire only for new URLs or stale Filed by values, so a board
# that's already in sync costs ~7 API calls regardless of board size.

set -euo pipefail

PROJECT_OWNER=alunduil
PROJECT_TITLE=Inbox
FILED_BY_FIELD_NAME='Filed by'
SEARCH_LIMIT=1000
# Comfortable headroom above the current ~520 items on the board.
PROJECT_LIMIT=5000

if [[ -n ${INBOX_SYNC_TOKEN:-} ]]; then
  export GH_TOKEN=${INBOX_SYNC_TOKEN}
fi

# Resolve project and field IDs by title/name so disaster-recovery (board
# recreation) doesn't strand this script. Mirrors the lookup-by-title
# pattern in scripts/bootstrap-projects.sh.
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

declare -A existing_id existing_filed

while IFS=$'\t' read -r url filed item_id; do
  [[ -z $url ]] && continue
  existing_id[$url]=$item_id
  existing_filed[$url]=$filed
done < <(
  gh project item-list "${PROJECT_NUMBER}" --owner "${PROJECT_OWNER}" \
    --format json --limit "${PROJECT_LIMIT}" \
    --jq '.items[] | select(.content.url) | "\(.content.url)\t\(.["filed by"] // "")\t\(.id)"'
)

owner_args=(--owner=alunduil --owner=dungeon-studio --owner=qua-world)
jq_pair='.[] | "\(.url)\t\(.author.login // "unknown")"'

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
  {
    gh search issues "${owner_args[@]}" --state=open --archived=false \
      --limit "${SEARCH_LIMIT}" --json url,author --jq "${jq_pair}"
    gh search prs "${owner_args[@]}" --state=open --archived=false \
      --limit "${SEARCH_LIMIT}" --json url,author --jq "${jq_pair}"
    gh search issues --author=alunduil --state=open --archived=false \
      --limit "${SEARCH_LIMIT}" --json url,author --jq "${jq_pair}"
    gh search issues --assignee=alunduil --state=open --archived=false \
      --limit "${SEARCH_LIMIT}" --json url,author --jq "${jq_pair}"
    gh search prs --author=alunduil --state=open --archived=false \
      --limit "${SEARCH_LIMIT}" --json url,author --jq "${jq_pair}"
    gh search prs --assignee=alunduil --state=open --archived=false \
      --limit "${SEARCH_LIMIT}" --json url,author --jq "${jq_pair}"
  } | sort -u
)

printf 'done: added=%d updated=%d skipped=%d\n' "$added" "$updated" "$skipped"
