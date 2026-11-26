#!/bin/bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Fails a Renovate update whose plan changes resources, unless Renovate holds
# the update for the admin to merge.
#
# Usage: scripts/check-renovate-plan.sh <pull-request.json> <resource-changes>
#
# <pull-request.json> is the response to GET /repos/{owner}/{repo}/pulls/{number}.
# <resource-changes> is the plan's count of managed resources it changes.

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

# Calling input makes jq fail on an empty file instead of printing nothing
# and succeeding.
body="$(jq -nr 'input | .body // ""' "${pull_request}")"
auto_merge="$(jq -nr 'input | .auto_merge != null' "${pull_request}")"

# The body quotes upstream release notes, which can include the Disabled
# text, so Enabled wins.
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

# Renovate leaves GitHub auto-merge on when it starts holding an update, so
# GitHub would merge it as soon as this check passed.
if [[ ${auto_merge} == true ]]; then
  echo "::error::This held update changes resources and auto-merge is on."
  echo "::notice::Turn auto-merge off, then re-run this job."
  exit 1
fi

echo "::notice::This held update changes resources; read the plan before merging."
