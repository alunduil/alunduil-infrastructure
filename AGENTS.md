<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# alunduil-infrastructure — agent guide

## Contribution flow

- **Open draft PRs only.** alunduil reviews and merges; changes
  reach `main` only that way.
- **Leave `terraform apply` to CI.** Merging a PR to `main` applies
  it. CI posts `terraform plan` as a comment on every PR touching
  Terraform; local `just alunduil` is break-glass only. Approve a
  merge only once that plan looks right.
- **Follow-ups to a merged PR land in a new session and a new PR.**

## Tooling inventory

Check these before writing new tooling:

- Helper scripts: `scripts/`, where new shell helpers go.
  State-bucket bootstrap: `bootstrap-terraform-state.sh`.
- Estate assets, the trust levels reaching them, entry points, and
  credentials with their consumers: `docs/reference/asset-register.md`,
  cited by ID. Component inventory (models, serial numbers, firmware,
  location) lives in a private Notion base. Adding or removing an
  asset updates the register in the same PR.
- GitHub Projects v2: `github/projects/` is a self-contained module,
  since no Terraform provider covers Projects v2. It is an intended
  exception to the `scripts/` rule; keep it there.
- Remote host configuration: `ansible/`, decided in ADR 0005.
- Renovate (`renovate.json`) handles dependency PRs; new pins go in
  its config.
- Credentials: `docs/how-to/bootstrap.md` names the env vars the
  bootstrap needs; the Cloudflare scopes live in
  `docs/how-to/create-bootstrap-cloudflare-token.md`. Don't enumerate
  token paths in committed files.

## Scope discipline

Merging applies, so an unrelated edit ships infra the reviewer didn't
ask for.

- Confirm scope doesn't overlap sibling or linked issues before
  opening the PR; ask if uncertain.
- An issue blocked by unshipped prerequisites: propose deferral
  with a `blocked-by` edge.
- Revert incidental edits (formatting, drive-by tweaks) before
  requesting review.

## Layout

- Terraform: `terraform/alunduil/`. One environment (personal infra;
  no dev/prod split).
- Repository settings — default branch, protection ruleset, Pages,
  topics, environments — are declarative in
  `terraform/alunduil/repositories.tf` via the `github_repository`
  module. Assume a repo setting lives there before treating it as
  manual.
- Adding a new repo to the org: create it with `gh` after
  confirming, since the CI App can't create user repos. Then land
  the `repositories.tf` map entry and an adoption `import` block in
  one draft PR, omitting inputs that match the module defaults. A
  follow-up PR removes the `import` after apply.

## Gotchas

- `alunduil.com` DNS is on Cloudflare, not Cloud DNS. Run
  `dig NS alunduil.com` before treating a Terraform DNS resource as
  authoritative.
- Hooks in `.pre-commit-config.yaml` run under `prek` and must pass.
  Run `prek install` once per clone. New files need SPDX headers;
  `reuse lint` rejects files without them.
- `vale` lints prose. Errors block a commit; warnings don't.
  - README and `docs/`: the full style set.
  - Agent-read Markdown (`AGENTS.md`, `CLAUDE.md`, `.claude/**`):
    spelling, casing, inclusive language, wordiness, and banned
    terms. A new agent-read file joins this `.vale.ini` section.
  - Everything else: spelling, casing, and inclusive language.
  - New terms go in `accept.txt` under
    `.vale/styles/config/vocabularies/`: `(?i)` for common nouns,
    exact casing for product names.

## Agent configuration

- This file holds every rule an agent needs, whatever the tool.
- A tool that doesn't read `AGENTS.md` gets the thinnest config
  that points at it — an import or a filename setting — plus only
  what is true of that tool alone. `CLAUDE.md` is the model.
