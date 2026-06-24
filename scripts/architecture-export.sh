#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Regenerate SVG diagram views from docs/architecture/workspace.dsl.
# Source of truth is the DSL; the .svg files are committed so GitHub
# renders the diagrams natively. Two stages: Structurizr exports the
# DSL to standalone PlantUML (no external includes, renders offline),
# then PlantUML renders each view to SVG. SPDX for the generated SVGs
# lives in REUSE.toml.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)/docs/architecture"

# Drop generated outputs so removed views don't linger as stale files.
find . -maxdepth 1 -name 'structurizr-*.puml' -delete
find . -maxdepth 1 -name '*.svg' -delete

# DSL -> standalone PlantUML.
docker run --rm --user "$(id -u):$(id -g)" \
    -v "$PWD:/usr/local/structurizr" \
    structurizr/structurizr export \
    -w workspace.dsl -f plantuml -o . >/dev/null

# Structurizr emits a "-key" legend diagram per view; the main views suffice.
find . -maxdepth 1 -name 'structurizr-*-key.puml' -delete

# PlantUML -> SVG.
docker run --rm --user "$(id -u):$(id -g)" \
    -v "$PWD:/data" -w /data \
    plantuml/plantuml -tsvg structurizr-*.puml >/dev/null

# The JRE writes a fontconfig cache under its user.home, which resolves to a
# literal "?" because the --user uid has no passwd entry. Drop the stray dir.
rm -rf -- '?'

# Rename structurizr-<View>.svg to the lowercase view slug.
for svg in structurizr-*.svg; do
    view=${svg#structurizr-}
    view=${view%.svg}
    slug=$(echo "$view" | tr '[:upper:]' '[:lower:]')
    mv -f "$svg" "$slug.svg"
done

rm -f structurizr-*.puml
