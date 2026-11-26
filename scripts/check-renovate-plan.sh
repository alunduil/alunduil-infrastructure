#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Fails a Renovate update whose plan changes resources, unless Renovate holds
# it and auto-merge is off.
#
# Usage: scripts/check-renovate-plan.sh <pull-request.json> <resource-changes>
#
# <pull-request.json> is the response to GET /repos/{owner}/{repo}/pulls/{number}.
# <resource-changes> is the number of managed resources the plan changes.

if [[ $# -ne 2 ]]; then
  echo "usage: ${0##*/} <pull-request.json> <resource-changes>" >&2
  exit 2
fi

pull_request="$1"
resource_changes="$2"

if [[ ! ${resource_changes} =~ ^[0-9]+$ ]]; then
  echo "::error::The plan's resource change count reads as '${resource_changes}'."
  exit 1
fi

# jq exits 0 on an empty file unless the filter calls input.
body="$(jq -nr 'input | .body // ""' "${pull_request}")"
auto_merge="$(jq -nr 'input | .auto_merge != null' "${pull_request}")"

# Release notes quoted in the body can contain the Disabled text, so Enabled
# takes precedence.
case "${body}" in
  *'**Automerge**: Enabled'*) held=false ;;
  *'**Automerge**: Disabled'*) held=true ;;
  *)
    echo "::error::The body states neither automerge Enabled nor Disabled."
    exit 1
    ;;
esac

if [[ ${resource_changes} == 0 ]]; then
  exit 0
fi

if [[ ${held} != true ]]; then
  echo "::error::Merging applies the plan's ${resource_changes} resource changes."
  echo "::notice::After reading the plan, the admin can bypass this check."
  exit 1
fi

# Renovate leaves auto-merge on when it holds an update, so passing here
# would let GitHub merge the update.
if [[ ${auto_merge} == true ]]; then
  echo "::error::This held update changes resources and auto-merge is on."
  echo "::notice::Turn auto-merge off, then re-run this job."
  exit 1
fi

echo "::notice::This held update changes resources; read the plan before merging."
