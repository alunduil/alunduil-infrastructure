#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# bootstrap-projects.sh — apply declarative GitHub Projects v2 schema specs
# from scripts/projects/*.json. Idempotent: a clean re-run is a strict no-op.
#
# Why bash? The integrations/github Terraform provider does not support
# Projects v2 — the feature request for the smallest piece was closed
# NOT_PLANNED in 2025-05. pulumi-github wraps the same provider and inherits
# the gap. No maintained community provider exists. A spec-driven script is
# the cheapest way to keep schema in version control without authoring and
# maintaining a custom provider for one project board.
#
# Threshold: this approach is fine for one board but doesn't scale past two
# or three. See #90 for the planned replacement (Python tool with separate
# spec and state).
#
# Pairs with #62 (Inbox item sync workflow): bootstrap rarely, sync hourly.
#
# Spec shape (see scripts/projects/inbox.json):
#   {
#     "owner": "<github-login>",
#     "title": "<project title>",
#     "fields": [
#       {
#         "name": "...",
#         "type": "SINGLE_SELECT",
#         "options": [
#           { "id": "<stable id>", "name": "...", "color": "GRAY|...",
#             "description": "..." }
#         ]
#       },
#       { "name": "...", "type": "TEXT" }
#     ]
#   }
#
# Option IDs are preserved across runs: when an option is renamed in the UI,
# matching by ID restores the canonical name without orphaning items already
# in that option. Fields not in a spec are left alone — we never delete a
# user-added field.
#
# Auth: uses the local `gh` CLI's authenticated identity. The token needs
# the `project` scope; if missing, run `gh auth refresh -s project`.
#
# Output: per-project KEY=VALUE block on stdout. KEYs are prefixed with the
# spec filename (basename, uppercased) so multiple specs do not collide. The
# block is suitable for `eval` or `grep`.

# GraphQL queries are single-quoted on purpose: $foo inside them is GraphQL
# variable syntax, not bash expansion.
# shellcheck disable=SC2016

set -euo pipefail

SPECS_DIR="${SPECS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/projects}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Submit a GraphQL request from query + variables; surface errors.
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

# Normalize "Filed by" → "FILED_BY" etc. for variable-name use.
to_key() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9' '_' | sed 's/_*$//'
}

# Project the spec's desired options onto the current options, preserving IDs
# where possible: match each spec option by ID first (rename recovery), then
# by name, else emit with no id so GitHub assigns a new one. Description
# defaults to "" for new options. Args: current-options-json,
# spec-options-json. Echoes converged-options-json (jq -c).
converge_options() {
  local current=$1 spec=$2
  jq -c -n \
    --argjson current "$current" \
    --argjson spec "$spec" \
    '
    $spec | map(
      . as $s
      | (
          ($current | map(select(.id == $s.id))[0])
          // ($current | map(select(.name == $s.name))[0])
        ) as $match
      | {
          id: ($match.id // null),
          name: $s.name,
          color: $s.color,
          description: ($s.description // "")
        }
      | with_entries(select(.value != null))
    )
    '
}

# Semantic deep-equal of current vs converged options on the fields we
# manage (id, name, color, description). Args: current-options-json,
# desired-options-json. Exit 0 if equal, 1 if not.
options_equal() {
  local current=$1 desired=$2
  jq -e -n --argjson c "$current" --argjson d "$desired" '
    ($c | map({id, name, color, description}))
    ==
    ($d | map({id: (.id // null), name, color, description: (.description // "")}))
  ' >/dev/null
}

# Resolve a Project v2 by title under owner; create if missing.
# Echoes "<id>|<number>|<url>".
resolve_project() {
  local owner=$1 title=$2

  local matches count
  matches=$(
    gh project list --owner "$owner" --limit 100 --format json |
      jq -c --arg title "$title" \
        '.projects | map(select(.title == $title))'
  )
  count=$(jq 'length' <<<"$matches")

  if [[ $count -gt 1 ]]; then
    echo "Multiple projects titled '$title' under @$owner; aborting." >&2
    return 1
  fi

  if [[ $count -eq 1 ]]; then
    jq -r '.[0] | "\(.id)|\(.number)|\(.url)"' <<<"$matches"
    return
  fi

  echo "  Creating project '$title' under @$owner..." >&2
  gh project create --owner "$owner" --title "$title" --format json |
    jq -r '"\(.id)|\(.number)|\(.url)"'
}

# Fetch all fields for a project, including SINGLE_SELECT option metadata
# (colors and descriptions — `gh project field-list` omits these).
fetch_fields() {
  local project_id=$1
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

# Apply one SINGLE_SELECT field spec. Creates if missing; converges options
# (preserving IDs to avoid orphaning items) if present.
apply_single_select() {
  local project_id=$1 current_fields=$2 spec=$3

  local name desired_options
  name=$(jq -r '.name' <<<"$spec")
  desired_options=$(jq -c '.options' <<<"$spec")

  local existing
  existing=$(
    jq -c --arg name "$name" '
      map(select(.__typename == "ProjectV2SingleSelectField" and .name == $name))
      | .[0] // null
    ' <<<"$current_fields"
  )

  if [[ $existing == "null" ]]; then
    echo "  Creating SINGLE_SELECT field '$name'..." >&2
    local create_options
    create_options=$(jq -c 'map({name, color, description: (.description // "")})' <<<"$desired_options")
    graphql 'mutation($projectId: ID!, $name: String!, $options: [ProjectV2SingleSelectFieldOptionInput!]!) {
      createProjectV2Field(input: {
        projectId: $projectId,
        dataType: SINGLE_SELECT,
        name: $name,
        singleSelectOptions: $options
      }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
    }' "$(jq -n --arg pid "$project_id" --arg name "$name" --argjson opts "$create_options" \
      '{projectId: $pid, name: $name, options: $opts}')" \
      >/dev/null
    return
  fi

  local field_id current_options converged
  field_id=$(jq -r '.id' <<<"$existing")
  current_options=$(jq -c '.options' <<<"$existing")
  converged=$(converge_options "$current_options" "$desired_options")

  if options_equal "$current_options" "$converged"; then
    echo "  '$name' (SINGLE_SELECT) up to date." >&2
    return
  fi

  echo "  Converging '$name' (SINGLE_SELECT) options..." >&2
  graphql 'mutation($fieldId: ID!, $options: [ProjectV2SingleSelectFieldOptionInput!]!) {
    updateProjectV2Field(input: { fieldId: $fieldId, singleSelectOptions: $options }) {
      projectV2Field { ... on ProjectV2SingleSelectField { id } }
    }
  }' "$(jq -n --arg fid "$field_id" --argjson opts "$converged" \
    '{fieldId: $fid, options: $opts}')" \
    >/dev/null
}

# Apply one TEXT/NUMBER/DATE field spec. Creates if missing; no-op if
# present with matching dataType.
apply_simple_field() {
  local project_number=$1 owner=$2 current_fields=$3 spec=$4

  local name type
  name=$(jq -r '.name' <<<"$spec")
  type=$(jq -r '.type' <<<"$spec")

  local existing
  existing=$(
    jq -c --arg name "$name" '
      map(select(.name == $name)) | .[0] // null
    ' <<<"$current_fields"
  )

  if [[ $existing != "null" ]]; then
    local current_type
    current_type=$(jq -r '.dataType' <<<"$existing")
    if [[ $current_type != "$type" ]]; then
      echo "Field '$name' exists with dataType $current_type (spec wants $type); refusing to mutate." >&2
      return 1
    fi
    echo "  '$name' ($type) up to date." >&2
    return
  fi

  echo "  Creating $type field '$name'..." >&2
  gh project field-create "$project_number" --owner "$owner" \
    --name "$name" --data-type "$type" >/dev/null
}

# Print PREFIX_KEY=value lines for the project itself and for each field in
# the spec (built-in fields not in the spec are omitted as noise). PREFIX is
# the spec filename basename, uppercased; multiple specs do not collide.
print_ids() {
  local prefix=$1 project_id=$2 project_number=$3 project_url=$4
  local spec=$5 final_fields=$6

  printf '%s_PROJECT_URL=%s\n' "$prefix" "$project_url"
  printf '%s_PROJECT_ID=%s\n' "$prefix" "$project_id"
  printf '%s_PROJECT_NUMBER=%s\n' "$prefix" "$project_number"

  while IFS=$'\t' read -r typename name field_id; do
    local field_key
    field_key=$(to_key "$name")
    printf '%s_FIELD_%s_ID=%s\n' "$prefix" "$field_key" "$field_id"
    if [[ $typename == "ProjectV2SingleSelectField" ]]; then
      while IFS=$'\t' read -r opt_name opt_id; do
        local opt_key
        opt_key=$(to_key "$opt_name")
        printf '%s_OPTION_%s_%s_ID=%s\n' "$prefix" "$field_key" "$opt_key" "$opt_id"
      done < <(
        jq -r --arg fid "$field_id" '
          .[] | select(.id == $fid) | .options[]? | [.name, .id] | @tsv
        ' <<<"$final_fields"
      )
    fi
  done < <(
    jq -r --argjson fields "$(jq -c '[.fields[].name]' "$spec")" '
      .[] | select(.name as $n | $fields | index($n)) | [.__typename, .name, .id] | @tsv
    ' <<<"$final_fields"
  )
}

apply_spec() {
  local spec=$1
  local prefix
  prefix=$(to_key "$(basename "$spec" .json)")

  local owner title
  owner=$(jq -r '.owner' "$spec")
  title=$(jq -r '.title' "$spec")

  echo "==> $title (@$owner) [spec: $(basename "$spec")]" >&2

  local resolved project_id project_number project_url
  resolved=$(resolve_project "$owner" "$title")
  IFS='|' read -r project_id project_number project_url <<<"$resolved"

  local current_fields
  current_fields=$(fetch_fields "$project_id")

  local field_count
  field_count=$(jq '.fields | length' "$spec")
  local i field_spec field_type
  for ((i = 0; i < field_count; i++)); do
    field_spec=$(jq -c --argjson i "$i" '.fields[$i]' "$spec")
    field_type=$(jq -r '.type' <<<"$field_spec")
    if [[ $field_type == "SINGLE_SELECT" ]]; then
      apply_single_select "$project_id" "$current_fields" "$field_spec"
    else
      apply_simple_field "$project_number" "$owner" "$current_fields" "$field_spec"
    fi
  done

  local final_fields
  final_fields=$(fetch_fields "$project_id")
  print_ids "$prefix" "$project_id" "$project_number" "$project_url" "$spec" "$final_fields"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Skip main when sourced (e.g. by tests/bootstrap-projects.bats).
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  return 0 2>/dev/null || true
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

shopt -s nullglob
specs=()
for path in "$SPECS_DIR"/*.json; do
  [[ $path == *.schema.json ]] && continue
  specs+=("$path")
done
if [[ ${#specs[@]} -eq 0 ]]; then
  echo "No specs found in $SPECS_DIR" >&2
  exit 1
fi

for spec in "${specs[@]}"; do
  apply_spec "$spec"
done
