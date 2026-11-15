<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Release controls by actor

Which control stops each actor from starting an unreviewed release, and which
established behaviour that control relies on.

Verified 2026-11-15.

## Scope

Written for the operator planning controls against the [release path threat
model](threat-model-release-path.md). It assumes the [asset
register](../reference/asset-register.md), [credential
reachability](credential-reachability.md), and [release control
behaviour](../reference/release-control-behaviour.md).

It also treats two planned controls as in place: the tag ruleset in #1055, and a
default-branch check in each release workflow (`zfs-replicate#827`,
`network-arbitrary#172`). Neither exists. Without the tag ruleset, any actor
with `Contents` write can create a release tag ([credential
reachability](credential-reachability.md#tagging)).

Out of scope:

- Routes into this repository's `main` other than hook-fix commits.
  [Credential reachability](credential-reachability.md) covers them.
- Codecov (P-9), whose route is a spoofed check name (#429).

## What the two controls stop

The tag ruleset refuses a matching tag from any user or App without a bypass
entry,
on [all three tested
routes](../reference/release-control-behaviour.md#tag-creation-routes). The
routes include creating a Release with a new tag. On every tested route, the
release App's bypass entry exempts the App, and the admin role's bypass entry
exempts a fine-grained token acting as the account.

The default-branch check refuses to publish a tag whose commit isn't on the
default branch. GitHub runs the release workflow from the tagged commit, so a
workflow in that commit without the check publishes the tag unchecked.

## What withholding `Workflows` stops

Withholding `Workflows` lets the default-branch check stop an actor only while
no branch carries a release workflow without the check. An actor without
`Workflows` [can tag a commit whose workflow files exist on some
branch](../reference/release-control-behaviour.md#tagging-without-workflows).
Renovate (P-6), the Claude App (P-8), and any other actor with `Workflows`
write can push a branch whose release workflow lacks the check.

## Actors

### Write collaborators (P-7)

The tag ruleset refuses their release tags, because no bypass entry names
them. Review gates their merges.

### Hook fix (P-5, using C-25)

The tag ruleset refuses the hook-fix App's release tags, because no bypass
entry names it.

The required job planned in #1057 would stop a hook-fix commit reaching a
default branch until the operator approves it. Without the job, Renovate
automerges a branch carrying hook-fix commits. Renovate [treats a branch as
unmodified when the author email of every commit is in
`gitIgnoredAuthors`](../reference/release-control-behaviour.md#modified-branch-detection),
and the shared preset lists the hook-fix App's email there
([`renovate-config@a67936f`, `default.json:12-14`](https://github.com/alunduil/renovate-config/blob/a67936f66c9a2dfa4d38f99a64822e19ee35474f/default.json#L12-L14)).
In `alunduil/projects-v2-sync#49`, `renovate[bot]` merged an
`alunduil-hook-fix[bot]` commit with no review.

The job would rely on three behaviours:

- [A failed run keeps the check
  failing](../reference/release-control-behaviour.md#failed-runs-of-a-required-check),
  so a second job with the same name can't pass it.
- [A passing re-run of the failed run clears the
  failure](../reference/release-control-behaviour.md#re-running-a-failed-run),
  so a review-triggered workflow can re-run the job after approval without
  another credential.
- [GitHub signs an API commit from a bot only when the bot sends it with no
  custom author](../reference/release-control-behaviour.md#bot-commit-signing),
  so a credential other than Renovate's can't forge a verified `renovate[bot]`
  commit.

### Renovate (P-6)

The operator accepts Renovate's access ([credential
reachability](credential-reachability.md#why-renovate-and-the-claude-app-are-accepted)).
The tag ruleset refuses Renovate's release tags, because no bypass entry names
it.

Renovate raises a re-pointed action tag as a [`digest`
update](../reference/release-control-behaviour.md#moved-tags-behind-digest-pins),
unless `digestOneAndOnly` is set and another update is present. The rules that
govern digest updates therefore govern re-pointed tags.

`matchFileNames` [tests only the upgrade's
files](../reference/release-control-behaviour.md#matchfilenames-scope), so a
path rule can't hold back a later commit on the same branch.

### Claude App (P-8)

The tag ruleset refuses the Claude App's release tags, because no bypass entry
names it. The App holds `Workflows` write, so withholding `Workflows` doesn't
limit it. The operator accepts its other routes ([credential
reachability](credential-reachability.md#why-renovate-and-the-claude-app-are-accepted)).

### Release App (P-12)

The release App is the one actor meant to create release tags, so the tag
ruleset gives it a bypass entry [by App
ID](../reference/release-control-behaviour.md#app-bypass), beside the admin
role's. The entry exempts the App, so the ruleset doesn't limit which commit
the App tags. Only the default-branch check stops a
leaked key, and only [while no branch carries a release workflow without the
check](#what-withholding-workflows-stops).

### `GITHUB_TOKEN` (P-11)

Tags and Releases that `GITHUB_TOKEN` creates start no workflow (register,
P-11), so it can't start a release by tagging.

### Tokens acting as the account (C-13, C-32)

C-32 is a fine-grained token acting as the account, the kind of token
tested in #1065. The
[admin role's
bypass](../reference/release-control-behaviour.md#admin-role-bypass) exempts
it, so it can create release tags despite the ruleset. If C-32 holds
`Administration` write, it [can also add a bypass entry or delete the
ruleset](../reference/release-control-behaviour.md#ruleset-edits-by-account-tokens).
The register lists its scope as `Unverified`. The ruleset can't stop C-32, so
issue #738 tracks removing the token.

C-13 is a classic token. No test, documentation, or source shows whether the
admin role's bypass exempts a classic token ([not
established](../reference/release-control-behaviour.md#not-established)), so
issues #1076 and #1069 shouldn't assume either answer.
