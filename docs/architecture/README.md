<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Architecture

C4 model ([c4model.com](https://c4model.com)) of every system alunduil
runs personally — repos, GCP and Cloudflare infra, workstation, MCP
fleet, home systems. Diátaxis classification: *explanation*.

## Views

- [System Landscape](system-landscape.md) — Level 1, every system.
- [Containers — alunduil-infrastructure](container-infra.md) — Level 2.
- [Containers — GCP project](container-gcp.md) — Level 2.
- [Containers — GitHub](container-github.md) — Level 2.
- [Containers — Cloudflare](container-cloudflare.md) — Level 2.

Systems tagged `Stub` (workstation, MCP fleet, home network) are
placeholders — their Level 2 containers land via interview-driven
discovery as the surface is captured.

## Tooling

[Structurizr DSL](https://docs.structurizr.com/dsl) as the
single-source-of-truth model in [`workspace.dsl`](workspace.dsl).
Per-view Mermaid markdown is generated from the DSL and committed
alongside so GitHub renders the diagrams natively in PR diffs.

Why Structurizr over hand-written Mermaid: one model, many views.
Adding a system or container shows up in every view that references
it, with no parallel updates to keep in sync. The cost is
`structurizr-cli` in the dev loop — wrapped in
[`scripts/architecture-export.sh`](../../scripts/architecture-export.sh),
which runs the published Docker image.

## Regenerating after a DSL change

```sh
scripts/architecture-export.sh
```

Re-runs the export and overwrites the per-view `*.md` files in this
directory. Requires Docker. Pre-commit invokes the same script
automatically on changes to `workspace.dsl`.
