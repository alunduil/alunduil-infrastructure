---
name: scaffold-repo
description: Scaffold a new GitHub repository for the alunduil org end to end. Classifies each github_repository module input as shared/archetype-shared/specific against the module and the existing repositories.tf, creates the repo (confirmed, via gh) so Terraform can adopt it, emits the module block plus the adoption import in one draft PR, and files a follow-up to remove the import after apply. Use when adding a repo to terraform/*/repositories.tf.
---

# Scaffold a new repository

Drive a new repo from name + intent to a draft PR CI can apply cleanly. The
`github_repository` module and the `repositories.tf` files are the source
of truth for the shared-vs-specific split — derive it every run, never from
a snapshot.

Two hard rules:

- Never run `terraform apply`/`plan` locally. CI applies on merge and posts
  the plan on the PR — that comment is the clean/not-clean signal.
- Create the repo through `gh` under the operator's token, as a confirmed
  step — never the Terraform provider (the CI App can't create user repos).

## Gather

- Repo name — help pick one when the intent is firmer than the name.
- Intent: language / archetype, release flow, Pages, discussions, template
  seed.
- Does the repo already exist, and on what default branch? Picks the path.

## Classify (the code is the source of truth)

1. Read `modules/github_repository/variables.tf` for inputs + defaults, and
   `main.tf` for settings hardcoded on every repo (public visibility,
   squash-only merges, secret scanning, the default ruleset, vuln alerts).
   Those aren't inputs — never restate them in a block.
2. Read every `terraform/*/repositories.tf`; tally each input's values.
3. Classify each input:
   - **Shared** — matches the module default; leave it unset.
   - **Archetype-shared** — set across the cluster the repo joins; copy its
     value.
   - **Specific** — varies per repo; ask (`description`, `topics`,
     `homepage_url`). Write `description` active-voice and second-person,
     saying when the reader would reach for the repo — ddbeck's Evaluate
     criterion: why / what it achieves, not what it's made of. No
     "CLI that…" / "library for…" openers; lead with the verb. See the
     `readme` skill.
4. Archetype clusters (re-derive values from the members — hint, not
   inventory):
   - Haskell library (`*.hs` / `haskell-library` topic): haskell +
     hypermedia topics; published → `environments = ["hackage"]`; older →
     `default_branch = "master"`.
   - Static site / Pages: `pages` + `homepage_url` + a build check;
     `github-pages` topic.
   - Rust/WASM plugin, CLI: topic conventions only.
5. Draft `module "<name_underscored>"` (dots/dashes → underscores), setting
   only archetype-shared and specific values in declaration order. Leave
   `=` alignment to `terraform_fmt`.

## Path A — net-new repo

1. Confirm, then create (external state — show the command, pause):

   ```bash
   gh repo create alunduil/<name> --public --add-readme --description "<desc>"
   ```

   `--add-readme` is required: it seeds a commit on `main` so
   `github_branch_default` has a branch to point at. Empty repo → apply
   fails setting the default branch.
2. Add the module block and, beside it, the repository import (import
   blocks are illegal in child modules):

   ```hcl
   import {
     to = module.<name>.github_repository.this
     id = "<name>"
   }
   ```

   Repository resource only — a fresh repo has no `default` ruleset, so the
   module creates it. Don't import the ruleset.

## Path B — adopt an existing untracked repo

1. Add the module block + repository import (as in Path A, no create).
2. Repo already has a hand-made `default` ruleset → first apply hits 422
   "Name must be unique". Import it too, id from
   `gh api repos/alunduil/<name>/rulesets` (the `default` entry):

   ```hcl
   import {
     to = module.<name>.github_repository_ruleset.default_branch
     id = "<name>:<ruleset_id>"
   }
   ```

3. Live default branch is `master` → set `default_branch = "master"`, or
   rename via GitHub's UI first (the module's `check` block fails the plan
   on a mismatch).

## Land it (both paths)

1. pre-commit → commit → push → draft PR; the body notes the import(s)
   adopt on first apply and are removed afterward.
2. File a follow-up issue (`issue-create` skill) to remove the import(s) —
   they can't go until apply puts the resource in state, post-merge. Link
   it from the PR body.

## Out-of-Terraform notes (whichever apply)

- SPDX/REUSE headers on new files (`.tf` inline; `REUSE.toml` covers
  `.claude/**`, JSON, lock files).
- Environment secrets (e.g. the Hackage token for
  `environments = ["hackage"]`) are injected out of band.
- Pages: set `https_enforced = true` only after GitHub issues the cert
  (tick "Enforce HTTPS" in the UI first). The apex CNAME lives in
  Cloudflare DNS, not Cloud DNS.
