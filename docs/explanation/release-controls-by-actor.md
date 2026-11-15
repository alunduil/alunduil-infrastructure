<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Release controls by actor

Why each actor that can start a release needs its own control, and which
platform behaviour each control rests on.

Verified 2026-11-15.

## Scope

Written for the operator planning controls against the [release path threat
model](threat-model-release-path.md). It assumes the [asset
register](../reference/asset-register.md) and [credential
reachability](credential-reachability.md). Links to [release control
behaviour](../reference/release-control-behaviour.md) mark what a test or
source established.

Out of scope:

- Routes into this repository's `main` other than hook-fix commits.
  [Credential reachability](credential-reachability.md) covers them.
- Codecov (P-9), whose route is a spoofed check name (#429).

## Why no single control holds everyone

Today nothing stops a new tag, as [credential
reachability](credential-reachability.md#tagging) explains. Two controls could
reach every repository's tags, and neither would hold every actor.

The tag ruleset #1055 plans refuses a matching tag on [all three tested
routes](../reference/release-control-behaviour.md#tag-creation-routes),
including a Release that would create one. It would hold anyone left off its
bypass list. Each bypass entry is an exemption, though, and the [admin role's
entry](../reference/release-control-behaviour.md#admin-role-bypass) reaches
tokens acting as the admin. A token with `Administration` write [can rewrite
the ruleset
itself](../reference/release-control-behaviour.md#ruleset-edits-by-admin-tokens).

The second control is each release workflow's check that its tag is on the
default branch (`zfs-replicate#827`, `network-arbitrary#172`). That check runs
from the tagged commit, so it holds only actors that can't pick a commit
without it. Withholding the `Workflows` permission looks like it guarantees
that, and it doesn't. An actor without it [can still tag any commit whose
workflow files exist on some
branch](../reference/release-control-behaviour.md#tagging-without-workflows).
Any actor holding `workflows` write, such as Renovate (P-6) or the Claude App
(P-8), can push such a branch, including one where the check is removed.
Withholding the permission stops an actor writing new workflow content, not
releasing workflow content someone else pushed.

So the ruleset would decide who creates release tags, and the default-branch
check holds an actor only while no branch carries a release workflow without
it. The sections below describe each actor once both are in place.

## Actors

### Write collaborators (P-7)

The tag ruleset holds them, because they never appear on its bypass list.
That's the whole control for tagging. Review still gates their merges.

### Hook fix (P-5, using C-25)

The hook-fix App stays off the tag ruleset's bypass list, so the ruleset holds
its tags on repositories the ruleset covers. Its missing `Workflows`
permission is no substitute, for the [reason
above](#why-no-single-control-holds-everyone).

Its route to a default branch needs a separate control, #1057's required job.
The job rests on four behaviours:

- [A failed run keeps the check
  failing](../reference/release-control-behaviour.md#failed-runs-of-a-required-check),
  so a second passing job can't clear it.
- [Re-running the failed run clears
  it](../reference/release-control-behaviour.md#re-running-a-failed-run), so
  an approval clears the gate through a review-triggered re-run with no extra
  credential.
- [Only commits a bot authors itself are verified as that
  bot](../reference/release-control-behaviour.md#bot-commit-verification), so
  a verified `renovate[bot]` commit can't be forged with another key.
- [Renovate judges a branch unmodified by author
  email](../reference/release-control-behaviour.md#modified-branch-detection),
  so Renovate's own automerge holds nothing back here.

### Renovate (P-6)

Renovate is an accepted trust, as [credential
reachability](credential-reachability.md#why-renovate-and-the-claude-app-are-accepted)
explains, and it isn't a bypass actor on the tag ruleset. What matters about
it here is the updates it raises. A re-pointed action tag [arrives as a
`digest`
update](../reference/release-control-behaviour.md#moved-tags-behind-digest-pins)
unless `digestOneAndOnly` drops it beside another update, so whatever rule
holds digest updates holds a moved tag. `matchFileNames` [sees only the
upgrade's files](../reference/release-control-behaviour.md#matchfilenames-scope),
so a path hold can't stop a later commit on the same branch.

### Claude (P-8)

The tag ruleset holds its tags, because no ruleset names it. Withholding
`Workflows` isn't available as a control, since the App holds `workflows`
write. Its other routes are accepted for the reasons [credential
reachability](credential-reachability.md#why-renovate-and-the-claude-app-are-accepted)
gives.

### Release App (P-12)

It's the one actor meant to create release tags, so it's the tag ruleset's
second bypass entry, [named by its App
ID](../reference/release-control-behaviour.md#app-bypass). The exemption
covers all three tested routes, so the ruleset can't constrain which commit
the App tags. That leaves the default-branch check, which holds a leaked key
only under the [condition
above](#why-no-single-control-holds-everyone).

### `GITHUB_TOKEN` (P-11)

Tags and Releases it creates start no workflow, as the register records, so
it can't start a release by tagging. No test covered it against the tag
ruleset.

### Tokens acting as the account (C-13, C-32)

C-32 is a fine-grained token acting as the account, the kind tested. It gets
the admin role's bypass, so it creates release tags past the ruleset. Whether
it can also rewrite the ruleset depends on `Administration` write, and the
register lists its scope as `Unverified`. The ruleset can't hold it, and
removing the token is the control (#738).

C-13 is a classic token. Whether a classic token gets the bypass [isn't
established](../reference/release-control-behaviour.md#not-established), so
issues #1076 and #1069 shouldn't assume either answer.
