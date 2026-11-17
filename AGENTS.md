<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# alunduil-infrastructure — agent guide

## Contribution flow

- **Open draft PRs only.** Don't push to `main`; don't merge your
  own PRs. alunduil reviews and merges.
- **Don't run `terraform apply`.** Merging a PR to `main` triggers
  the apply in CI. `terraform plan` runs in CI on every PR touching
  Terraform and posts its output as a comment; local `just alunduil`
  is break-glass only. Approve a merge only once the plan comment
  looks right — merging applies it.
- **Follow-ups land in a new session and a new PR.** A merged PR
  is done — don't keep iterating on it for adjacent work.

## Tooling inventory

Before scripting from first principles or hitting APIs by hand,
check what's already in place:

- Helper scripts: `scripts/`. New shell helpers go here, not the
  repo root. State-bucket bootstrap: `bootstrap-terraform-state.sh`.
- Estate assets, the trust levels reaching them, entry points, and
  credentials with their consumers: `docs/reference/asset-register.md`,
  cited by ID. Component inventory (models, serial numbers, firmware,
  location) lives in a private Notion base, not here. Adding or
  removing an asset updates the register in the same PR.
- GitHub Projects v2: self-contained module at `github/projects/`
  (applier `bootstrap.sh` + `*.bats` tests + `*.json`
  specs + `project.schema.json`), co-located for locality absent a
  Projects v2 provider. #90 tracks the declarative replacement.
  Deliberate exception to the `scripts/` rule above — don't move it
  back.
- Remote host configuration: `ansible/`, decided in ADR 0005.
- Renovate (`renovate.json`) handles dependency PRs; extend the
  config rather than pinning by hand.
- Credentials: `docs/how-to/bootstrap.md` names the env vars the
  bootstrap needs; the Cloudflare scopes live in
  `docs/how-to/create-bootstrap-cloudflare-token.md`. Don't enumerate
  token paths in committed files.

## Scope discipline

`terraform apply` runs in CI on merge to `main`, so an unrelated edit
in a scoped PR ships infra the reviewer didn't ask for.

- Confirm scope doesn't overlap sibling or linked issues before
  opening the PR; ask if uncertain.
- An issue blocked by unshipped prerequisites: propose deferral
  with a `blocked-by` edge rather than write code ahead of them.
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
- Adding a new repo to the org: create it with `gh` (confirm first;
  the CI App can't create user repos), then land the
  `repositories.tf` map entry plus an adoption `import` block in one
  draft PR. Leave inputs at their module defaults unset. A follow-up
  removes the `import` after apply.

## Gotchas

- `alunduil.com` DNS is on Cloudflare, not Cloud DNS. Run
  `dig NS alunduil.com` before treating a TF DNS resource as
  authoritative.
- Hooks in `.pre-commit-config.yaml` run under `prek` and must pass.
  Run `prek install` once per clone. New files need SPDX headers —
  REUSE flags missing ones.
- `vale` lints prose. Full style set on README and `docs/`; spelling,
  casing, and inclusive language everywhere else, plus wordiness and
  banned terms on agent-read Markdown (`AGENTS.md`, `CLAUDE.md`,
  `.claude/**`); a new agent-read file joins that `.vale.ini`
  section. Errors block a commit, warnings don't. New terms go in `accept.txt` under
  `.vale/styles/config/vocabularies/`, `(?i)` for common nouns, exact
  casing for product names.

## Agent configuration

- This file holds every rule an agent needs, whatever the tool.
- A tool that doesn't read `AGENTS.md` gets the thinnest config
  that points at it — an import or a filename setting — plus only
  what is true of that tool alone. `CLAUDE.md` is the model.
