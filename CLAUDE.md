<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

<!--
Maintainer notes (HTML comments are stripped from Claude's context):
- AI-targeted, loaded every session. Optimise for tokens; keep
  under ~75 lines.
- Add an entry only when Claude has made the same mistake twice
  or a non-obvious convention bit a session.
- Prefer pointers (README §..., file:line) over copies of content
  that already lives elsewhere.
- Human-facing context lives in [README](README.md); no
  CONTRIBUTING.md (single maintainer; outside contributions are
  not solicited).
-->

# alunduil-infrastructure — Claude guide

## Contribution flow

- **Open draft PRs only.** Don't push to `main`; don't merge your
  own PRs. alunduil reviews and merges.
- **Don't run `terraform apply`.** alunduil runs it on `main`
  post-merge from the local shell. `terraform plan` output in the
  PR body is welcome.
- **Follow-ups land in a new session and a new PR.** A merged PR
  is done — don't keep iterating on it for adjacent work.

## Tooling inventory

Before scripting from first principles or hitting APIs by hand,
check what's already in place:

- Helper scripts: `scripts/`. New shell helpers go here, not the
  repo root. State-bucket bootstrap: `bootstrap-terraform-state.sh`.
- Renovate (`renovate.json`) handles dependency PRs; extend the
  config rather than pinning by hand.
- Credentials: README §"Running an apply" names the env vars
  needed; §"Stays manual" covers the Cloudflare scopes and the
  `TF_VAR_cloudflare_api_token` workaround. Don't enumerate token
  paths in committed files.

## Scope discipline

`terraform apply` runs out-of-band post-merge, so an unrelated edit
in a scoped PR ships infra the reviewer didn't ask for.

- Confirm scope doesn't overlap sibling or linked issues before
  opening the PR; ask if uncertain.
- An issue blocked by unshipped prerequisites: propose deferral
  with a `blocked-by` edge rather than write premature code.
- Revert incidental edits (formatting, drive-by tweaks) before
  requesting review.

## Layout

- Terraform: `terraform/alunduil/`. One environment (personal infra;
  no dev/prod split).
- Manual steps that stay outside Terraform: README §"Stays manual".
  Check there before assuming a thing should live in `.tf`.

## Architecture model

`docs/architecture/workspace.dsl` is the C4 model for this repo's
slice (cloud, GitHub, home network). When you add a system,
container, or significant relationship, update the DSL in the same
PR. Pre-commit re-runs `scripts/architecture-export.sh` (Docker
required) and regenerates the SVG `*.svg` views.

Workstation and MCP-fleet Level 2 live in `alunduil-chezmoi`'s C4 —
same contract, different repo. Don't add chezmoi-managed surface
here.

## Gotchas

- `alunduil.com` DNS is on Cloudflare, not Cloud DNS. Run
  `dig NS alunduil.com` before treating a TF DNS resource as
  authoritative.
- Pre-commit hooks (REUSE, terraform_fmt/validate, markdownlint,
  yamllint, detect-secrets) must pass. New files need SPDX
  headers — REUSE flags missing ones.
