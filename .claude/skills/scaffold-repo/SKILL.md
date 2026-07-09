---
name: scaffold-repo
description: Scaffold a new GitHub repository for the alunduil org end to end. Classifies each github_repository module input as shared/archetype-shared/specific against the module and the existing repositories.tf, creates the repo (confirmed, via gh) so Terraform can adopt it, emits the module block plus the adoption import in one draft PR, and files a follow-up to remove the import after apply. Use when adding a repo to terraform/*/repositories.tf.
---

# Scaffold a new repository

Drive a new repo from name + intent to a draft PR that CI can apply
cleanly: classify the module inputs, create the repo (confirmed) so
Terraform can adopt it, and land the adoption `import` in the same PR. The
`github_repository` module and the `repositories.tf` files are the source
of truth for the shared-vs-specific split — derive it every run, not from a
snapshot.

Never run `terraform apply`/`plan` locally — CI applies on merge and posts
the plan on the PR. Repo creation goes through `gh` under the operator's
token as a confirmed step (the CI GitHub App can't create user repos); it
is never silent and never uses the Terraform GitHub provider to side-effect
the repo into existence.

## Gather

- Repo name — help pick one when the intent is firmer than the name.
- Intent: language / archetype, release flow, GitHub Pages, discussions,
  template seed. Whether the repo already exists, and on what default
  branch.

## Classify (source of truth = the code)

1. Read `modules/github_repository/variables.tf` (inputs + defaults) and
   `main.tf` (settings hardcoded on every repo — public visibility,
   squash-only merges, secret scanning, the default ruleset, vulnerability
   alerts). Those hardcoded ones are not inputs; never restate them.
2. Read every `terraform/*/repositories.tf` and tally each input's value
   distribution across the module blocks.
3. Classify each input for the new repo:
   - **Shared** — matches the module default; leave it unset.
   - **Archetype-shared** — set across the cluster the repo joins; copy
     the cluster's value.
   - **Specific** — varies per repo; ask (`description`, `topics`,
     `homepage_url`).
4. Archetype clusters — re-derive values from the members, this is a hint
   not an inventory:
   - Haskell library (`*.hs` name or `haskell-library` topic): haskell /
     hypermedia topics; published ones set `environments = ["hackage"]`;
     older ones predate `main` (`default_branch = "master"`).
   - Static site / Pages: `pages` block + `homepage_url` + a build status
     check; `github-pages` topic.
   - Rust/WASM plugin, CLI: topic conventions only so far.
5. Draft `module "<name_underscored>"` (dots and dashes → underscores)
   setting only archetype-shared and specific values, in the module's
   declaration order. Leave `=` alignment to `terraform_fmt`.

## Path A — net-new repo (you're inventing it)

1. Create the repo as a confirmed step (external state — show the command
   and pause before running):

   ```bash
   gh repo create alunduil/<name> --public --add-readme --description "<desc>"
   ```

   `--add-readme` is required: it seeds an initial commit on `main` so
   `github_branch_default` has a branch to point at. Against an empty repo,
   apply fails when it tries to set the default branch.
2. Add the module block **and** its adoption import beside it — import
   blocks are illegal in child modules, so they live in `repositories.tf`:

   ```hcl
   import {
     to = module.<name>.github_repository.this
     id = "<name>"
   }
   ```

   Import only the repository resource. A fresh repo has no `default`
   ruleset, so the module creates it — do **not** import the ruleset here.
3. pre-commit, commit, push, draft PR. The body notes the import adopts the
   repo on first apply and is removed afterward.
4. File a follow-up issue (use the `issue-create` skill) to remove the
   import block once apply has landed — it can't be removed until the
   resource is in state, which happens post-merge. Link it from the PR
   body.

## Path B — adopt an existing untracked repo

1. No create. Add the module block + the repository import (as in Path A).
2. If the repo already carries a hand-made `default` ruleset, the first
   apply hits 422 "Name must be unique" — add its import too, with the id
   from `gh api repos/alunduil/<name>/rulesets` (the entry named `default`):

   ```hcl
   import {
     to = module.<name>.github_repository_ruleset.default_branch
     id = "<name>:<ruleset_id>"
   }
   ```

3. If the live default branch is `master`, set `default_branch = "master"`
   or rename via GitHub's UI first — the module's `check` block fails the
   plan on a mismatch.
4. pre-commit, commit, push, draft PR; follow-up issue to remove the
   import(s) post-apply.

## Remaining out-of-Terraform notes (include whichever apply)

- SPDX/REUSE headers on new files (`.tf` inline; `REUSE.toml` covers
  `.claude/**`, JSON, lock files).
- Environment secrets (e.g. the Hackage token for
  `environments = ["hackage"]`) are injected out of band, not by Terraform.
- Pages: `https_enforced` can only be set `true` after GitHub issues the
  cert — tick "Enforce HTTPS" in the UI first. The apex CNAME lives in
  Cloudflare DNS, not Cloud DNS; add it there.

## Finish

Show the module block, the create command (Path A), and the checklist.
Never apply. Open the draft PR per the repo's contribution flow.
