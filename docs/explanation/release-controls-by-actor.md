<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Release controls by actor

Why each actor that can start a release needs its own control, and which
platform behaviour each control rests on.

Verified 2026-11-15.

## Scope

Written for the operator planning controls against the [release path threat
model](threat-model-release-path.md). It assumes the [asset
register](../reference/asset-register.md), [credential
reachability](credential-reachability.md), and [release control
behaviour](../reference/release-control-behaviour.md). The actor sections
assume two planned controls are in place: #1055's tag ruleset and each release
workflow's default-branch check.

Out of scope:

- Routes into this repository's `main` other than hook-fix commits.
  [Credential reachability](credential-reachability.md) covers them.
- Codecov (P-9), whose route is a spoofed check name (#429).

## Why no single control holds everyone

Nothing stops a new tag yet ([credential
reachability](credential-reachability.md#tagging)). Two planned controls
reach every repository's tags, and neither holds every actor.

The tag ruleset planned in #1055 refuses a matching tag on [all three tested
routes](../reference/release-control-behaviour.md#tag-creation-routes),
including a Release that would create one. It holds anyone left off its
bypass list. Each bypass entry is an exemption, and the [admin role's
entry](../reference/release-control-behaviour.md#admin-role-bypass) reaches
tokens acting as the admin. A token with `Administration` write [can rewrite
the ruleset
itself](../reference/release-control-behaviour.md#ruleset-edits-by-admin-tokens).

Each release workflow's default-branch check (`zfs-replicate#827`,
`network-arbitrary#172`) runs from the tagged commit, so it holds only actors
that can't pick a commit without it. Withholding `Workflows` doesn't stop the
pick. An actor without it [can tag any commit whose workflow files exist on
some branch](../reference/release-control-behaviour.md#tagging-without-workflows),
and any actor with `workflows` write, such as Renovate (P-6) or the Claude App
(P-8), can push one where the check is removed. The check therefore holds an
actor only while no branch carries a release workflow without it.

## Actors

### Write collaborators (P-7)

The tag ruleset holds their tags, because they're never on its bypass list.
Review gates their merges.

### Hook fix (P-5, using C-25)

The hook-fix App stays off the tag ruleset's bypass list, so the ruleset holds
its tags. Its missing `Workflows` permission is [no
substitute](#why-no-single-control-holds-everyone).

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

Renovate is an [accepted
trust](credential-reachability.md#why-renovate-and-the-claude-app-are-accepted)
and isn't a bypass actor on the tag ruleset. A re-pointed action tag [arrives
as a
`digest`
update](../reference/release-control-behaviour.md#moved-tags-behind-digest-pins)
unless `digestOneAndOnly` drops it beside another update, so whatever rule
holds digest updates holds a moved tag. `matchFileNames` [sees only the
upgrade's files](../reference/release-control-behaviour.md#matchfilenames-scope),
so a path hold can't stop a later commit on the same branch.

### Claude (P-8)

The tag ruleset holds its tags, because no ruleset names it. Withholding
`Workflows` isn't available as a control, since the App holds `workflows`
write. Its other routes are [accepted
trust](credential-reachability.md#why-renovate-and-the-claude-app-are-accepted).

### Release App (P-12)

It's the one actor meant to create release tags, so it's the tag ruleset's
second bypass entry, [named by its App
ID](../reference/release-control-behaviour.md#app-bypass). The exemption
covers all three tested routes, so the ruleset can't constrain which commit
the App tags. A leaked key is held only by the default-branch check, under its
[limit](#why-no-single-control-holds-everyone).

### `GITHUB_TOKEN` (P-11)

Tags and Releases it creates start no workflow (register, P-11), so it can't
start a release by tagging. No test covered it against the tag
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
