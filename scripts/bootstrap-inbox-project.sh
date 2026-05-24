#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# bootstrap-inbox-project.sh — idempotent provisioning of the Inbox
# Projects v2 board.
#
# Project: https://github.com/users/alunduil/projects/3
# Pairs with #62 (item sync workflow): bootstrap rarely, sync hourly.
#
# This script's job is disaster recovery and drift correction. The project
# was created manually on 2026-05-17; a clean re-run is a strict no-op. If
# someone renames a Status option in the UI, re-running puts the canonical
# name back without orphaning items (matching is ID-first).
#
# Auth: uses the local `gh` CLI's authenticated identity. The token needs
# the `project` scope; if it doesn't, run `gh auth refresh -s project`.
#
# Output: KEY=VALUE lines on stdout so callers can `eval` or grep for IDs.

# GraphQL queries are single-quoted on purpose: $foo inside them is GraphQL's
# own variable syntax, not bash expansion. Suppress the noise globally.
# shellcheck disable=SC2016

set -euo pipefail

OWNER="${OWNER:-alunduil}"
PROJECT_TITLE="${PROJECT_TITLE:-Inbox}"

FILED_BY_FIELD_NAME="Filed by"

# Canonical Status options. IDs reflect the live project (3) — when an option
# is renamed in the UI, the ID lets us put the canonical name back without
# orphaning items in that option. On a fresh project, GitHub assigns new IDs
# and the literals here become informational; lookups fall back to name.
# Descriptions are not managed: whatever exists is preserved, and new options
# start with an empty description.
STATUS_OPTIONS_JSON='[
  {"id": "8080c408", "name": "Backlog", "color": "GRAY"},
  {"id": "bcc940da", "name": "Review",  "color": "YELLOW"},
  {"id": "c090564c", "name": "Closed",  "color": "GREEN"}
]'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Submit a GraphQL request and surface errors. Args: query, variables-json.
graphql() {
  local query=$1
  local variables=${2:-'{}'}
  local response
  response=$(
    jq -n --arg q "$query" --argjson v "$variables" \
      '{query: $q, variables: $v}' |
      gh api graphql --input -
  )
  if jq -e '.errors' <<<"$response" >/dev/null 2>&1; then
    echo "GraphQL request failed:" >&2
    jq '.errors' <<<"$response" >&2
    return 1
  fi
  printf '%s' "$response"
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------

if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Resolve the project (by title; create if absent)
# ---------------------------------------------------------------------------

owner_id=$(
  graphql 'query($login: String!) { user(login: $login) { id } }' \
    "$(jq -n --arg login "$OWNER" '{login: $login}')" |
    jq -r '.data.user.id'
)

matches=$(
  graphql 'query($login: String!) {
    user(login: $login) {
      projectsV2(first: 100) { nodes { id title number url } }
    }
  }' "$(jq -n --arg login "$OWNER" '{login: $login}')" |
    jq -c --arg title "$PROJECT_TITLE" \
      '.data.user.projectsV2.nodes | map(select(.title == $title))'
)

match_count=$(jq 'length' <<<"$matches")
if [[ $match_count -gt 1 ]]; then
  echo "Found $match_count projects titled '$PROJECT_TITLE' under @$OWNER; ambiguous, aborting." >&2
  exit 1
fi

if [[ $match_count -eq 0 ]]; then
  echo "Creating Projects v2 board '$PROJECT_TITLE' under @$OWNER..." >&2
  project=$(
    graphql 'mutation($ownerId: ID!, $title: String!) {
      createProjectV2(input: { ownerId: $ownerId, title: $title }) {
        projectV2 { id title number url }
      }
    }' "$(jq -n --arg ownerId "$owner_id" --arg title "$PROJECT_TITLE" \
      '{ownerId: $ownerId, title: $title}')" |
      jq -c '.data.createProjectV2.projectV2'
  )
else
  project=$(jq -c '.[0]' <<<"$matches")
fi

project_id=$(jq -r '.id' <<<"$project")
project_number=$(jq -r '.number' <<<"$project")
project_url=$(jq -r '.url' <<<"$project")

# ---------------------------------------------------------------------------
# 2. Fetch current fields
# ---------------------------------------------------------------------------

fetch_fields() {
  graphql 'query($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        fields(first: 50) {
          nodes {
            __typename
            ... on ProjectV2FieldCommon { id name dataType }
            ... on ProjectV2SingleSelectField {
              options { id name color description }
            }
          }
        }
      }
    }
  }' "$(jq -n --arg pid "$project_id" '{projectId: $pid}')" |
    jq -c '.data.node.fields.nodes'
}

fields_json=$(fetch_fields)

# ---------------------------------------------------------------------------
# 3. Converge the Status field's options
# ---------------------------------------------------------------------------

status_field=$(
  jq -c '
    map(select(.__typename == "ProjectV2SingleSelectField" and .name == "Status"))
    | .[0] // null
  ' <<<"$fields_json"
)

if [[ $status_field == "null" ]]; then
  echo "Status field is missing — Projects v2 should always provide it. Aborting." >&2
  exit 1
fi

status_field_id=$(jq -r '.id' <<<"$status_field")
current_status_options=$(jq -c '.options' <<<"$status_field")

# Build the desired option list: for each canonical option, preserve the
# existing option's ID if we can match by id-or-name (id wins, so a rename
# in the UI is reverted without losing items). Otherwise, omit id so the
# API creates a new option.
desired_status_options=$(
  jq -c -n \
    --argjson current "$current_status_options" \
    --argjson canonical "$STATUS_OPTIONS_JSON" \
    '
    $canonical | map(
      . as $c
      | (
          ($current | map(select(.id == $c.id))[0])
          // ($current | map(select(.name == $c.name))[0])
        ) as $match
      | {
          id: ($match.id // null),
          name: $c.name,
          color: $c.color,
          description: ($match.description // ""),
        }
      | with_entries(select(.value != null))
    )
    '
)

current_norm=$(
  jq -c '[.[] | {id, name, color, description}]' <<<"$current_status_options"
)
desired_norm=$(
  jq -c '
    [.[] | {
      id:          (.id // null),
      name:        .name,
      color:       .color,
      description: (.description // "")
    }]
  ' <<<"$desired_status_options"
)

if [[ $current_norm == "$desired_norm" ]]; then
  echo "Status options up to date." >&2
else
  echo "Converging Status options..." >&2
  graphql 'mutation($fieldId: ID!, $options: [ProjectV2SingleSelectFieldOptionInput!]!) {
    updateProjectV2Field(input: {
      fieldId: $fieldId,
      singleSelectOptions: $options
    }) {
      projectV2Field {
        ... on ProjectV2SingleSelectField {
          options { id name color }
        }
      }
    }
  }' "$(jq -n --arg fid "$status_field_id" --argjson opts "$desired_status_options" \
    '{fieldId: $fid, options: $opts}')" \
    >/dev/null
fi

# ---------------------------------------------------------------------------
# 4. Ensure the "Filed by" text field exists
# ---------------------------------------------------------------------------

filed_by_field=$(
  jq -c --arg name "$FILED_BY_FIELD_NAME" '
    map(select(.name == $name)) | .[0] // null
  ' <<<"$fields_json"
)

if [[ $filed_by_field == "null" ]]; then
  echo "Creating '$FILED_BY_FIELD_NAME' text field..." >&2
  filed_by_field=$(
    graphql 'mutation($projectId: ID!, $name: String!) {
      createProjectV2Field(input: {
        projectId: $projectId,
        dataType: TEXT,
        name: $name
      }) {
        projectV2Field {
          ... on ProjectV2FieldCommon { id name dataType }
        }
      }
    }' "$(jq -n --arg pid "$project_id" --arg name "$FILED_BY_FIELD_NAME" \
      '{projectId: $pid, name: $name}')" |
      jq -c '.data.createProjectV2Field.projectV2Field'
  )
else
  current_type=$(jq -r '.dataType' <<<"$filed_by_field")
  if [[ $current_type != "TEXT" ]]; then
    echo "Field '$FILED_BY_FIELD_NAME' exists with dataType $current_type (expected TEXT); refusing to mutate." >&2
    exit 1
  fi
fi

filed_by_field_id=$(jq -r '.id' <<<"$filed_by_field")

# ---------------------------------------------------------------------------
# 5. Re-fetch and print the final state
# ---------------------------------------------------------------------------

final_fields=$(fetch_fields)
final_status_options=$(
  jq -c '
    map(select(.__typename == "ProjectV2SingleSelectField" and .name == "Status"))[0].options
  ' <<<"$final_fields"
)

option_id() {
  jq -r --arg name "$1" 'map(select(.name == $name))[0].id' <<<"$final_status_options"
}

cat <<EOF
PROJECT_URL=$project_url
PROJECT_ID=$project_id
PROJECT_NUMBER=$project_number
STATUS_FIELD_ID=$status_field_id
STATUS_OPTION_BACKLOG_ID=$(option_id Backlog)
STATUS_OPTION_REVIEW_ID=$(option_id Review)
STATUS_OPTION_CLOSED_ID=$(option_id Closed)
FILED_BY_FIELD_ID=$filed_by_field_id
EOF
