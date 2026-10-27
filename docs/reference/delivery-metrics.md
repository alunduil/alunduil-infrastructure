<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Delivery metrics

Definitions of the DORA and SPACE metrics the Grafana dashboards show,
each stated as the GitHub events and fields it reads. The dashboards,
and any hand count checking them, compute every metric the way this
page defines it.

## Scope

Covers repositories owned by `alunduil` that aren't archived or forks.
Each metric reads GitHub through the Grafana GitHub data source,
authenticated as a GitHub App. An App installation has its own GraphQL
rate limit, separate from the `alunduil` account's.

Out of scope:

- Repositories owned by `dungeon-studio` and `qua-world`.
- Team benchmarks and comparisons against the performance clusters in
  the DORA reports.

## Common terms

Window
: The dashboard's time range, 30 days by default. A metric counts an
  event when the event's end timestamp falls inside the window.

Your PR
: A pull request whose `author_login` is `alunduil`. Agent-assisted
  PRs opened under that login count. PRs authored by `renovate[bot]`,
  `dependabot[bot]`, or any other login don't count.

PR commit
: The commit a merged PR leaves on the default branch. Its `message`
  names the PR: `(#N)` at the end of a squash merge, or
  `Merge pull request #N` for a merge commit.

Deploy
: The event, defined per repository under
  [Deployment classification](#deployment-classification), that puts a
  change where its users get it.

Your deploy
: A deploy that ships at least one of your PRs. A deploy that ships
  only bot PRs is excluded from every metric.

## Deployment classification

Each repository with a deploy belongs to one of three classes. A class
names the data source query that finds deploys, the field that dates
them, and the signal that marks one as failed.

### Run class

- Deploy: a completed run of the repository's deploy workflow, filtered
  as listed below. Workflow Runs query.
- Deploy time: the run's `updated_at`.
- Failure signal: the run's `conclusion` is `failure`, or a revert PR.

A run whose `conclusion` is neither `success` nor `failure`, such as
`cancelled` or `skipped`, is neither a deploy nor a failure.

### Release class

- Deploy: a GitHub Release with `is_draft` and `is_prerelease` both
  false. Releases query.
- Deploy time: the release's `published_at`.
- Failure signal: a revert PR.

### Merge class

- Deploy: a PR merged to the default branch. Pull Requests query.
- Deploy time: the PR's `merged_at`.
- Failure signal: a revert PR.

### Repositories

| Repository | Class | Workflow | Filter |
| --- | --- | --- | --- |
| `alunduil-infrastructure` | Run | `Terraform Apply` | branch `main` |
| `blog.alunduil.com` | Run | `CD` | branch `main`, event `push` |
| `collection-json.hs` | Run | `Release` | event `workflow_dispatch` |
| `network-arbitrary` | Run | `Release` | event `release` |
| `zfs-replicate` | Run | `Release` | event `release` |
| `woodland-generators` | Release | — | — |
| `siren-json.hs` | Release | — | — |
| `renovate-config` | Merge | — | — |
| `alunduil-chezmoi` | Merge | — | — |
| `projects-v2-sync` | No deploy | — | — |
| `zellij-claude-pair` | No deploy | — | — |
| `git-worktree-poi` | No deploy | — | — |

Any other repository in scope has no deploy.

Filter notes:

- `blog.alunduil.com`: `CD` also runs on a schedule, rebuilding the
  site without a change. The `push` filter excludes those runs.
- `collection-json.hs`: a `release` event uploads a Hackage candidate.
  The `workflow_dispatch` run publishes to Hackage.
- `woodland-generators`: `Release` runs on every push to `main` and
  publishes only when release-please cuts a release, so the release
  itself is the deploy.

## Shipped PRs

Lead time and attribution need the PRs each deploy ships:

- Run class, `push` event: the PR whose PR commit is the run's
  `head_sha`.
- Run class, `release` or `workflow_dispatch` event: every PR merged
  after the previous successful deploy and at or before the release
  the run publishes.
- Release class: every PR merged after the previous release's
  `published_at` and at or before this release's.
- Merge class: the merged PR.

A failed deploy ships its PRs too. They count toward the failure and
ship again in the next successful deploy.

A PR that merges without triggering a deploy run, such as an
`alunduil-infrastructure` PR outside the `Terraform Apply` path filter,
ships nothing and appears in no DORA metric.

## Revert PRs

A revert PR is a merged PR whose title starts with `Revert`. The PR it
reverts is the one its title names, by number or by the quoted
original title. The deploy that first shipped the reverted PR counts
as failed. A revert PR is never one of your PRs for DORA, so it
doesn't count toward lead time.

## DORA metrics

### Deployment frequency

Count of your deploys, successful or failed, with deploy time in the
window, divided by the window length in weeks. Reported as deploys per
week.

### Lead time for changes

Median, over your PRs whose first successful deploy falls in the
window, of:

```text
first successful deploy time − PR created_at
```

For the Merge class this equals `merged_at − created_at`.

### Change failure rate

```text
your failed deploys in the window ÷ your deploys in the window
```

A deploy that fails both by its run conclusion and by a revert PR
counts once.

### Failed deployment recovery time

Median, over your failed deploys in the window, of:

```text
next successful deploy time − failed deploy time
```

The next successful deploy is the first later successful deploy in the
same repository. For a deploy failed by a revert PR, it's the first
successful deploy that ships the revert PR. A failed deploy with no
later successful deploy is excluded until one exists.

## SPACE metrics

Each metric covers your PRs across every repository in scope, whether
it has a deploy class or not.

### Satisfaction and well-being: Weekly satisfaction

Mean score of check-in issues closed in the window. Issues query,
fields `labels` and `closed_at`.

A check-in issue carries its score as exactly one label from
`satisfaction-1` to `satisfaction-5`. The Issues query returns labels
but not issue bodies. A check-in issue closed without a score label
doesn't count.

### Performance: PR merge rate

Your PRs merged in the window, divided by your PRs closed in the
window, merged or not. Pull Requests query, fields `merged` and
`closed_at`.

### Activity: PRs merged

Your PRs merged in the window, divided by the window length in weeks.
Pull Requests query, field `merged_at`.

### Communication and collaboration: Reviews given

Reviews submitted by `alunduil` in the window on PRs another login
authored, divided by the window length in weeks. Pull Request Reviews
query, fields `review_author_login`, `pull_request_author_login` and
`review_created_at`.

### Efficiency and flow: PR cycle time

Median `merged_at − created_at` of your PRs merged in the window. Pull
Requests query, fields `created_at` and `merged_at`.

## Hand counts

Each metric reproduces from these GitHub views for one repository and
one week. Replace the dates and repository name.

- Run class deploys: the workflow's page in the Actions tab, filtered
  by branch and event. Each run links to its commit, and the commit to
  its PR.
- Release class deploys: the repository's Releases page.
- Your merged PRs:

  ```text
  is:pr author:alunduil is:merged merged:2026-10-19..2026-10-25
  repo:alunduil/alunduil-infrastructure
  ```

- Your PRs closed without merging:

  ```text
  is:pr author:alunduil is:unmerged closed:2026-10-19..2026-10-25
  repo:alunduil/alunduil-infrastructure
  ```

- Revert PRs:

  ```text
  is:pr is:merged in:title Revert repo:alunduil/alunduil-infrastructure
  ```

- Reviews given, then each PR's conversation tab for review dates:

  ```text
  is:pr reviewed-by:alunduil -author:alunduil user:alunduil
  updated:2026-10-19..2026-10-25
  ```

Enter each search on one line; the line break above is for width.
