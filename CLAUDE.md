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
- **Don't run `terraform apply`.** Merging a PR to `main` triggers
  the apply in CI. `terraform plan` runs in CI on every PR and posts
  its output as a comment; local `just alunduil` is break-glass only.
- **Follow-ups land in a new session and a new PR.** A merged PR
  is done — don't keep iterating on it for adjacent work.

## Tooling inventory

Before scripting from first principles or hitting APIs by hand,
check what's already in place:

- Helper scripts: `scripts/`. New shell helpers go here, not the
  repo root. State-bucket bootstrap: `bootstrap-terraform-state.sh`.
- GitHub Projects v2: self-contained module at `github/projects/`
  (applier `bootstrap.sh` + `*.bats` tests + `*.json`
  specs + `project.schema.json`), co-located for locality absent a
  Projects v2 provider. #90 tracks the declarative replacement.
  Deliberate exception to the `scripts/` rule above — don't move it
  back.
- Renovate (`renovate.json`) handles dependency PRs; extend the
  config rather than pinning by hand.
- Credentials: `docs/how-to/bootstrap.md` names the env vars the
  bootstrap needs; the Cloudflare scopes live in
  `docs/how-to/create-master-cloudflare-token.md`. Don't enumerate
  token paths in committed files.

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
- Repository settings — default branch, protection ruleset, Pages,
  topics, environments — are declarative in
  `terraform/alunduil/repositories.tf` via the `github_repository`
  module. Assume a repo setting lives there before treating it as
  manual.

## Gotchas

- `alunduil.com` DNS is on Cloudflare, not Cloud DNS. Run
  `dig NS alunduil.com` before treating a TF DNS resource as
  authoritative.
- Pre-commit hooks (REUSE, terraform_fmt/validate, markdownlint,
  yamllint, detect-secrets) must pass. New files need SPDX
  headers — REUSE flags missing ones.
- The `terraform-plan` job posts the plan as a PR comment. Don't
  approve a merge until it looks right — merging applies it.
