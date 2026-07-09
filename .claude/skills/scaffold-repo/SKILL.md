---
name: scaffold-repo
description: Scaffold a new GitHub repository for the alunduil org as a Terraform github_repository module block. Reads the module and every repositories.tf, classifies each input as shared (inherit the default), archetype-shared (matches a cluster like Haskell library or static site), or specific (ask), emits a draft module block setting only the non-default values, and lists the steps Terraform can't do. Use when adding a repo to terraform/*/repositories.tf.
---

# Scaffold a new repository

Produce a draft `module ""` block for `terraform/<stack>/repositories.tf`
plus a checklist of steps Terraform can't perform. The `github_repository`
module and the `repositories.tf` files are the source of truth for the
shared-vs-specific split — derive it from them every run, don't trust a
snapshot.

Out of scope (never do these):

- `terraform apply` — CI applies on merge.
- Creating the repo through the GitHub API as a side effect. The skill
  emits Terraform. (The repo must still exist before apply can adopt it;
  the operator creates it out-of-band — see the checklist.)

## Gather

- Repo name (the GitHub slug).
- Intent: language / archetype, release flow, GitHub Pages, discussions,
  template seed, whether the repo already exists and on what branch.

## Method

1. Read `terraform/modules/github_repository/variables.tf` for the current
   input list and defaults, and `main.tf` for the settings hardcoded on
   every repo (public visibility, squash-only merges, secret scanning, the
   default ruleset, vulnerability alerts). Those hardcoded ones are not
   inputs — never restate them in a module block.
2. Read every `terraform/*/repositories.tf` and tally each input's value
   distribution across the module blocks.
3. Classify each input for the new repo:
   - **Shared** — the module default matches nearly every repo. Leave it
     unset so the block inherits it silently.
   - **Archetype-shared** — set across the cluster the new repo joins.
     Match the cluster (below), then copy its value.
   - **Specific** — varies per repo. Ask. (`description`, `topics`,
     `homepage_url` are always specific.)
4. Archetype clusters currently present — re-derive the actual values from
   the members, this list is a starting hint not an inventory:
   - Haskell library (`*.hs` name or `haskell-library` topic): shared
     topics (haskell / haskell-library / hypermedia); published ones set
     `environments = ["hackage"]`; older ones predate the `main`
     convention (`default_branch = "master"`).
   - Static site / GitHub Pages: `pages` block + `homepage_url` + a build
     status check; `github-pages` topic.
   - Rust/WASM plugin, CLI tool: topic conventions only so far.
5. Emit the block. Module label = repo name with dots and dashes turned
   into underscores (match existing blocks). Set only archetype-shared and
   specific values, in the module's declaration order. `terraform_fmt`
   aligns the `=`; leave that to pre-commit.

## Out-of-Terraform checklist (include whichever apply)

- **The repo must exist before apply.** The CI GitHub App can't
  `POST /user/repos` (403). The operator creates it out-of-band
  (`gh repo create`); then add a root `import` block adopting
  `module.<name>.github_repository.this` beside the module — import blocks
  aren't allowed in child modules (see the zellij-claude-pair precedent).
  Remove the import once applied.
- **A hand-created "default" ruleset** makes the first apply hit 422
  "Name must be unique". Add an import for
  `module.<name>.github_repository_ruleset.default_branch` with id
  `<repo>:<ruleset_id>`. Remove once applied.
- **Adopting an existing repo on `master`**: set
  `default_branch = "master"`, or rename via GitHub's UI
  (Settings → Branches → Rename) first. The module's `check` block fails
  the plan when the live default branch differs from the configured one.
- **SPDX/REUSE headers** on new files. `.tf` files take inline headers;
  `REUSE.toml` already covers `.claude/**`, JSON, and lock files.
- **Environment secrets** (e.g. the Hackage token for
  `environments = ["hackage"]`) are injected out of band, not by
  Terraform.
- **Pages**: `https_enforced` can only be set `true` after GitHub issues
  the Let's Encrypt cert — tick "Enforce HTTPS" in the UI first. The apex
  CNAME lives in Cloudflare DNS, not Cloud DNS; add it there.

## Finish

Show the module block and the checklist. Don't apply. Open a draft PR only
if asked, per the repo's contribution flow.
