<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Release control behaviour

What GitHub and Renovate do in the cases the release path's controls depend
on, and how each behaviour is known. [Release controls by
actor](../explanation/release-controls-by-actor.md) maps these behaviours to
actors.

Verified 2026-11-19.

## Scope

Written for the operator choosing or reviewing a control on the release path.
It assumes the [asset register](asset-register.md), whose IDs name the actors.

Out of scope:

- How this repository configures these controls. `main.tf` holds that.
- Organization-owned repositories. Every test ran on a personal account.

## Evidence

- **Tested**: run in a scratch personal-account repository for #1065 and
  #1174.
- **Documented**: quoted from GitHub's docs at
  [`github/docs@d59b263`](https://github.com/github/docs/tree/d59b2631959db46d71ca5f7748ec04311c6d0870).
- **Source**: read from Renovate at
  [`renovatebot/renovate@da96643`](https://github.com/renovatebot/renovate/tree/da9664321d4d16371084d616d2ac5c57de02e27d).

## Tag rulesets

### Tag creation routes

A tag ruleset with the `creation` rule refuses a matching tag from a user or
App without a bypass entry, on all three routes:

- `POST /git/refs`: `422 Reference update failed`
- `POST /releases` with a new `tag_name`: `422`, `Cannot create ref due to
  creations being restricted`
- `git push`: `GH013: Repository rule violations found`

`POST /releases` succeeds with a tag name outside the pattern.

Tested: [#1065, test 1](https://github.com/alunduil/alunduil-infrastructure/issues/1065#issuecomment-6892951283),
with an App and a fine-grained token.

Documented: [Available rules for
rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
says "only users with bypass permissions can create branches or tags whose
name matches the pattern you specify."

### App bypass

A bypass entry with `actor_type` `Integration` and `actor_id` set to the App
ID exempts that App on all three routes.

Tested: [#1065, test 2](https://github.com/alunduil/alunduil-infrastructure/issues/1065#issuecomment-6892951283).

### Admin role bypass

On a personal-account repository, GitHub accepts a bypass entry with
`actor_type` `RepositoryRole` and `actor_id` 5, the admin role. With that
entry, a fine-grained token acting as the account creates matching tags on all
three routes.
Without that entry the ruleset refuses the same token, because owning the
repository exempts nothing.

Tested: [#1065, tests 2 and
3](https://github.com/alunduil/alunduil-infrastructure/issues/1065#issuecomment-6892951283).

### Ruleset edits by tokens acting as the account

A fine-grained token acting as the account, with `Administration` write, can
add a bypass entry to a ruleset and delete the ruleset.

Tested: [#1065, test 3](https://github.com/alunduil/alunduil-infrastructure/issues/1065#issuecomment-6892951283).

### Bypass modes and actor types

- The `pull_request` bypass mode applies to branch rulesets only, so a tag
  ruleset's bypass is `always` or `exempt`.
- `OrganizationAdmin` isn't available on personal-account repositories.

Documented: [Rules](https://docs.github.com/en/rest/repos/rules).

## Tagging without `Workflows`

An actor holding `Contents` write but not `Workflows` can tag a commit only
when the workflow files of that commit already exist on some branch:

- On all three routes, the actor can tag a commit whose `.github/workflows/`
  differs from the default branch's but matches another branch's head.
- GitHub refuses a tag on a commit whose workflow files exist on no branch,
  such as the head of a deleted branch. `POST /git/refs` and `POST /releases`
  return `403 Resource not accessible by integration`, and `git push`
  returns `refusing to allow a GitHub App to create or update workflow ...
  without workflows permission`.

The same actor can't create a commit that adds a workflow: `POST /git/trees`
returns `403`.

A tag an App creates with `POST /git/refs` starts the workflows that run on
tag pushes, with the App as the run's actor.

Tested: [#1065, test 4](https://github.com/alunduil/alunduil-infrastructure/issues/1065#issuecomment-6892951283),
with an App. The workflow trigger: [#1174, hypothesis
3](https://github.com/alunduil/alunduil-infrastructure/issues/1174#issuecomment-6992373341).

Documented: the [`workflow`
scope](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)
allows workflow files when "the same file (with both the same path and
contents) exists on another branch in the same repository." The [Create a
release](https://docs.github.com/en/rest/releases/releases#create-a-release)
note compares against the default branch instead. Test 4 contradicts that
note.

## Required checks

### Failed runs of a required check

A failed run of a required job keeps the check failing on that commit. A
later passing run of a job with the same name, from another event and in
another check suite, doesn't clear the failure. GitHub refuses the merge with
`Required status check "Review gate" is failing.`

Tested: [#1065, test 5](https://github.com/alunduil/alunduil-infrastructure/issues/1065#issuecomment-6883231981).

### Re-running a failed run

Re-running a failed run replaces its check run in the same suite. When the
re-run passes, GitHub allows the merge. A workflow on `pull_request_review:
submitted`, with `actions: write`, can start the re-run by calling `POST
/actions/runs/{id}/rerun-failed-jobs` with `GITHUB_TOKEN`.

Tested: [#1065, test 5b](https://github.com/alunduil/alunduil-infrastructure/issues/1065#issuecomment-6892554032).

### Review-triggered runs

A `pull_request_review` run's checks count toward required checks. They attach
to the head commit, although `GITHUB_SHA` is the merge commit.

Documented: [Events that trigger
workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request_review)
gives `GITHUB_SHA`. [Troubleshooting required status
checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks)
lists `pull_request_review` among the events whose checks count, and says
"Required checks must pass on the latest commit SHA."

Tested, for the head-commit attachment: [#1065, test
5](https://github.com/alunduil/alunduil-infrastructure/issues/1065#issuecomment-6883231981).

## Custom deployment protection rules

An admin can enable a GitHub App subscribed to `deployment_protection_rule`,
with `Deployments` write and `Actions` read, as a rule on an environment. Each job
that targets the environment then waits for the App to approve or reject it,
through `POST /repos/{owner}/{repo}/actions/runs/{run_id}/deployment_protection_rule`.

### Visibility

GitHub enforces the rule on a public personal-account repository. On a private
one, GitHub accepts and lists the rule but doesn't enforce it: jobs run at
once and the App receives no webhook.

Tested: [#1174, hypothesis
1](https://github.com/alunduil/alunduil-infrastructure/issues/1174#issuecomment-6992373341).

### Webhook payload

The `requested` webhook carries the run's `sha`, `ref`, `environment`, and
`deployment_callback_url`.

Tested: [#1174, hypothesis
2](https://github.com/alunduil/alunduil-infrastructure/issues/1174#issuecomment-6992373341).

### Rejection

A rejected job fails before its first step, so it never reads the
environment's secrets. The rule binds whatever workflow the tagged commit
carries. A job in that commit that names no environment, or another
environment, gets none of this environment's secrets.

Tested: [#1174, hypotheses 3 and
4](https://github.com/alunduil/alunduil-infrastructure/issues/1174#issuecomment-6992373341),
with tags created by the admin and by an App.

### Unanswered requests

A job the App never answers keeps waiting. One unanswered run was still
waiting after 11.5 hours.

Tested: [#1174, hypothesis
5](https://github.com/alunduil/alunduil-infrastructure/issues/1174#issuecomment-7004497003).

### Required reviewers

On an environment with both the rule and a required reviewer, a job starts
only once both approve. A rejection from the App fails the job even after the
reviewer approved it.

Tested: [#1174, stacking with a required
reviewer](https://github.com/alunduil/alunduil-infrastructure/issues/1174#issuecomment-7004735308).

### Admin bypass

With `can_admins_bypass` set to `true`, the run page offers an admin **Start
all waiting jobs**, which starts the job without the App's approval. GitHub
records it as a `skipped` approval. `POST
/actions/runs/{id}/pending_deployments` from an admin's token returns `422 No
pending deployment requests to approve or reject`.

Tested: [#1174, admin
bypass](https://github.com/alunduil/alunduil-infrastructure/issues/1174#issuecomment-7004735308).

### Environment updates

`PUT /repos/{owner}/{repo}/environments/{name}`, the call Terraform's
`github_repository_environment` makes, leaves an enabled rule in place.

Tested: during [#1174's
runs](https://github.com/alunduil/alunduil-infrastructure/issues/1174#issuecomment-6992373341),
the rule stayed enabled through several environment updates.

## Bot commit signing

GitHub signs an API commit from a GitHub App or bot only when that App or bot
authenticates the request and the request sets no custom author, committer, or signature.

The GraphQL `createCommitOnBranch` mutation can't set an author or committer.
Its commits take the identity of whoever owns the credential that made the
request.

Documented: [About commit signature
verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#signature-verification-for-bots),
and the `createCommitOnBranch`
[schema](https://github.com/github/docs/blob/d59b2631959db46d71ca5f7748ec04311c6d0870/src/graphql/data/fpt/schema.docs.graphql#L28185-L28202).

## Renovate

### Re-pointed tags behind digest pins

For `uses: owner/action@<sha> # v7`, Renovate raises a re-pointed `v7` tag as
a `digest` update. With `digestOneAndOnly` set and another update present,
Renovate adds no digest update.

Source:
[`extract.ts:145-146`](https://github.com/renovatebot/renovate/blob/da9664321d4d16371084d616d2ac5c57de02e27d/lib/modules/manager/github-actions/extract.ts#L145-L146),
[`lookup/index.ts:594-601`](https://github.com/renovatebot/renovate/blob/da9664321d4d16371084d616d2ac5c57de02e27d/lib/workers/repository/process/lookup/index.ts#L594-L601),
[`utils.ts:94-96`](https://github.com/renovatebot/renovate/blob/da9664321d4d16371084d616d2ac5c57de02e27d/lib/workers/repository/process/lookup/utils.ts#L94-L96).

### `matchFileNames` scope

`matchFileNames` tests an upgrade's `packageFile` and `lockFiles`, not later
commits on the branch.

Source: [`files.ts:24-30`](https://github.com/renovatebot/renovate/blob/da9664321d4d16371084d616d2ac5c57de02e27d/lib/util/package-rules/files.ts#L24-L30).

### Modified-branch detection

Renovate treats a branch as unmodified when the author email of every commit
is in `gitIgnoredAuthors`, and keeps automerging it.

Source:
[`git/index.ts:1040-1047`](https://github.com/renovatebot/renovate/blob/da9664321d4d16371084d616d2ac5c57de02e27d/lib/util/git/index.ts#L1040-L1047).

## Not established

No test, documentation, or source covers these:

- Whether a classic personal access token, such as C-13, gets the admin role's
  bypass.
- Whether `POST /git/refs` and `git push` accept a tag name outside the
  pattern.
- Whether the tag ruleset refuses `GITHUB_TOKEN`.
- Whether a re-run started by `GITHUB_TOKEN` works on a pull request from a
  fork.
- How long a job waits on an unanswered custom deployment protection rule
  before it times out, and how the run then ends.
