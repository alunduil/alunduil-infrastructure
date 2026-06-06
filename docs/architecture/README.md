<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Architecture

C4 model ([c4model.com](https://c4model.com)) of the cloud and
home-network slice of alunduil's personal systems — Terraform-managed
GCP, Cloudflare, GitHub identity surface, plus the home network the
zone's DNS points at. Diátaxis classification: *explanation*.

The workstation-bounded slice — `workstation` and `MCP fleet` —
appears on this repo's Level 1 landscape as external systems but
its Level 2 lives in `alunduil-chezmoi`'s `docs/architecture/`,
where the configs actually live (chezmoi-managed). Each repo's
diagram updates in the same PR as the change that motivates it;
cross-repo "remember to update the diagram next door" is reliably
forgotten. Reader who wants the full picture reads both repos.

## Views

- [System Landscape](system-landscape.md) — Level 1, every system.
- [Containers — alunduil-infrastructure](container-infra.md) — Level 2.
- [Containers — GCP project](container-gcp.md) — Level 2.
- [Containers — GitHub](container-github.md) — Level 2.
- [Containers — Home network](container-homenetwork.md) — Level 2.
- [Deployment — Home network](deployment-homenetwork.md) — physical topology.
- [Trust model](trust-model.md) — hand-authored data-flow diagram of
  an apply's identity + secret path and its trust boundaries.

C4 strict: independently installable apps are Containers, not
Components. TrueNAS apps (Plex, Tailscale, observability) and SMB
shares are modeled as Containers of `Home network`. Where each runs —
TrueNAS / HAOS / Deco mesh / off-site NanoPi — is the Deployment view's
job, so the logical container view stays about what talks to what and
the deployment view carries placement.

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
