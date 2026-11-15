<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Release control behaviour

What GitHub and Renovate do in the cases the release path's controls depend
on, and how each behaviour is known. [Release controls by
actor](../explanation/release-controls-by-actor.md) explains which control
holds which actor.

Verified 2026-11-15.

## Scope

Written for the operator choosing or reviewing a control on the release path.
It assumes the [asset register](asset-register.md), whose IDs name the actors.

Each entry names its evidence:

- **Tested**: run in a scratch personal-account repository for #1065. The
  entry links the comment recording commands and responses.
- **Documented**: quoted from GitHub's docs at
  [`github/docs@d59b263`](https://github.com/github/docs/tree/d59b2631959db46d71ca5f7748ec04311c6d0870).
- **Source**: read from Renovate at
  [`renovatebot/renovate@da96643`](https://github.com/renovatebot/renovate/tree/da9664321d4d16371084d616d2ac5c57de02e27d).

Out of scope:

- How this repository configures these controls. `main.tf` holds that.
- Organization-owned repositories. Every test ran on a personal account.

## Tag rulesets

### The `creation` rule covers every way to create a tag

Tested ([#1065](https://github.com/alunduil/alunduil-infrastructure/issues/1065#issuecomment-6892951283),
test 1). A tag ruleset with `creation` refuses a matching tag from a
non-bypass actor through all three routes:

- `POST /git/refs`: `422 Reference update failed`
- `POST /releases` with a new `tag_name`: `422`, `Cannot create ref due to
  creations being restricted`
- `git push`: `GH013: Repository rule violations found`

A tag name outside the pattern is unaffected.

### An App is exempt by its App ID

Tested (test 2). A bypass entry with `actor_type` `Integration` and `actor_id`
set to the App ID exempts that App on all three routes. No other actor gains
anything from it.

### The admin role's bypass reaches tokens acting as the admin

Tested (tests 2 and 3). A personal-account repository accepts `actor_type`
`RepositoryRole` with `actor_id` 5, the admin role. A fine-grained token
created by the admin then creates matching tags on all three routes. Without
that entry the same token is refused: owning the repository exempts nothing.

### An admin token can rewrite any ruleset

Tested (test 3). A fine-grained token acting as the admin, with
`Administration` write, added a bypass entry to a ruleset and then deleted it.

### Bypass modes and actor types

Documented ([Rules](https://docs.github.com/en/rest/repos/rules)):

- The `pull_request` bypass mode applies to branch rulesets only, so a tag
  ruleset's bypass is `always` or `exempt`.
- `OrganizationAdmin` isn't available on personal repositories.

## The `Workflows` permission

### Without it, an actor tags only commits whose workflow files exist on a branch

Tested (test 4), with an App holding `Contents` write and no `Workflows`:

- The App tagged a commit whose `.github/workflows/` differs from the default
  branch's but matches another branch's head. It succeeded on all three routes.
- The App was refused on a commit whose workflow files exist on no branch,
  because its branch was deleted. Both APIs returned `403 Resource not
  accessible by integration`, and `git push` returned `refusing to allow a
  GitHub App to create or update workflow ... without workflows permission`.
- The App couldn't create a commit adding a workflow either: `POST /git/trees`
  returned `403`.

The [Create a
release](https://docs.github.com/en/rest/releases/releases#create-a-release)
note compares against the default branch, which the test contradicts. The
[`workflow`
scope](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)
wording matches it: workflow files are allowed when "the same file (with both
the same path and contents) exists on another branch in the same repository."

## Required checks

### A failed run blocks the check until that run passes

Tested ([#1065](https://github.com/alunduil/alunduil-infrastructure/issues/1065#issuecomment-6883231981),
test 5). A `pull_request` run of a required job failed, and a later
`pull_request_review` run of a job with the same name passed on the same head
commit. The two runs sat in separate check suites. The merge was refused with
`Required status check "Review gate" is failing.`

### Re-running the failed run clears it

Tested ([#1065](https://github.com/alunduil/alunduil-infrastructure/issues/1065#issuecomment-6892554032),
test 5b). A workflow on `pull_request_review: submitted`, with
`actions: write`, called `POST /actions/runs/{id}/rerun-failed-jobs` with
`GITHUB_TOKEN`. The re-run replaced the failed check run in its suite, and the
pull request merged.

### Review-triggered runs report on the head commit

Documented: `GITHUB_SHA` for `pull_request_review` is the merge commit
([Events that trigger
workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request_review)).
Tested in tests 5 and 5b: the check runs attached to the head commit.

Documented: `pull_request_review` is among the events whose checks count for a
pull request ([Troubleshooting required status
checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks)).
The same page says "Required checks must pass on the latest commit SHA."

## Commit verification

### A commit by a bot is verified only when it carries no custom author

Documented ([About commit signature
verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#signature-verification-for-bots)).
GitHub signs an API commit from a bot only when the request is authenticated
as that App or bot and sets no custom author, committer, or signature.

The GraphQL `createCommitOnBranch` mutation can't set an author or committer.
Its commits take the identity of whoever owns the credential that made the
request
([schema](https://github.com/github/docs/blob/d59b2631959db46d71ca5f7748ec04311c6d0870/src/graphql/data/fpt/schema.docs.graphql#L28185-L28202)).

## Renovate

### A moved tag behind a digest pin is a `digest` update

Source. For `uses: owner/action@<sha> # v7`, the extractor sets `currentValue`
to `v7` and `currentDigest` to the SHA
([`extract.ts:145-146`](https://github.com/renovatebot/renovate/blob/da9664321d4d16371084d616d2ac5c57de02e27d/lib/modules/manager/github-actions/extract.ts#L145-L146)).
Lookup then adds `updateType: 'digest'`
([`lookup/index.ts:594-601`](https://github.com/renovatebot/renovate/blob/da9664321d4d16371084d616d2ac5c57de02e27d/lib/workers/repository/process/lookup/index.ts#L594-L601)),
and keeps it when the tag's commit differs from the pin
([`utils.ts:94-96`](https://github.com/renovatebot/renovate/blob/da9664321d4d16371084d616d2ac5c57de02e27d/lib/workers/repository/process/lookup/utils.ts#L94-L96)).
With `digestOneAndOnly` set and another update present, no digest update is
added.

### `matchFileNames` sees only the upgrade's files

Source. The matcher tests `packageFile` and `lockFiles`, not later commits on
the branch
([`files.ts:24-30`](https://github.com/renovatebot/renovate/blob/da9664321d4d16371084d616d2ac5c57de02e27d/lib/util/package-rules/files.ts#L24-L30)).

### A branch counts as unmodified when its commit authors are ignored

Source. `isBranchModified` compares the author email of each commit with
`gitIgnoredAuthors`
([`git/index.ts:1040-1047`](https://github.com/renovatebot/renovate/blob/da9664321d4d16371084d616d2ac5c57de02e27d/lib/util/git/index.ts#L1040-L1047)).
`alunduil/projects-v2-sync#49` shows the effect: an `alunduil-hook-fix[bot]`
commit merged by `renovate[bot]` with no review.

## Not established

No test or source covers these:

- Whether a classic personal access token, such as C-13, gets the admin role's
  bypass.
- Whether a re-run started by `GITHUB_TOKEN` works on a pull request from a
  fork.
- Behaviour on organization-owned repositories.
