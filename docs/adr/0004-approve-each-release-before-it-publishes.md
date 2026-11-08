<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Approve each release before it publishes

- Status: Proposed
- Date: 2026-11-08

## Context and Problem Statement

Six repositories publish, or plan to. Every past release was cut by the
operator by hand. The 2027-02 milestones automate the path. A weekly job
opens a release pull request, a schedule or a person merges it, and
workflows tag, build, and publish.

Renovate already merges low-risk updates after green checks with no
review. Together with an unattended release, a compromised dependency
could merge and reach users with nobody looking. Uploads to Hackage and
PyPI can't be recalled.

The repositories ship in two ways:

- **Declared dependencies.** `collection-json.hs`, `network-arbitrary`,
  and `siren-json.hs` upload a source package to Hackage, and
  `zfs-replicate` uploads to PyPI. Each package holds only its own
  source. Consumers resolve its dependencies themselves.
- **Bundled dependencies.** `woodland-generators` attaches a
  `module.zip` that `esbuild` builds with `bundle: true`.
  `zellij-claude-pair` will attach a `.wasm` that statically links
  every crate in its `Cargo.lock`. Dependency code ships to users.

The [release path threat model](../explanation/threat-model-release-path.md)
lists routes to a publish that skip the merge:

- A forged release tag.
- A dispatch on an existing tag.
- Build code tampering with the package.
- A poisoned cache.

### Requirements

- **The irreversible step.** A person sees each release before an
  upload that can't be recalled.
- **Every route.** The check holds for every route to a publish, not
  only the merge.
- **What ships.** The check covers the bytes that publish, after they
  are built and tested.
- **Cadence.** Weekly releases need at most one human action each.

## Considered Options

- **Approve the release pull request merge.** It meets cadence. The
  pull request shows the version bump and changelog, not the dependency
  changes or the build. A forged tag, a dispatch, or build-time
  tampering never passes through it.
- **Release fully unattended, with detection.** It meets cadence, but no
  person sees a release. Alerts on an unexpected release (#1064) fire
  after an upload that can't be recalled.
- **Unattended where a package only declares its dependencies, with
  approval where it bundles them.** Both groups above need the approval:
  the first because its uploads can't be recalled, the second because
  dependency code ships. This collapses into approval everywhere.
- **Approve the publish job's environment.** It meets all four
  requirements.

## Decision Outcome

Chosen option: **approve the publish job's environment.**

Each publishing repository's upload or asset-attach job runs in an
environment that admits only release tags and requires the operator's
approval. Everything before it may run on a schedule, including merging
the release pull request. The approver reads the compare view since the
last tag. The changelog stays written for the project's consumers: users
of an application, developers using a library. It doesn't list
development or CI updates.

Renovate automerge and the release approval are separate gates.
Automerge decides what lands on the default branch without review. The
approval decides what reaches users. A change that automerge lands ships
only through a release, so the approval backs automerge up. Automerge
follows where a dependency runs:

- Updates to development, test, and CI-only dependencies automerge after
  green checks.
- Updates to anything a release job runs wait for review, because it
  runs before or alongside the job's credential. Those are the job's
  actions, the composite actions it calls, and its compiler and build
  tool pins.
- Updates to runtime dependencies a package bundles wait for review,
  because their code ships.

The approval reviews tested bytes only if the build is clean. The threat
model's findings on caches, build code sharing a job with a credential,
and untested artifacts close before any release runs unattended up to
the approval.

### Consequences

Good:

- One action per release, at the step that can't be undone, on bytes
  that have already been built and tested.
- The approval also stops a forged tag or a leaked release key from
  publishing.

Bad / accepted:

- The milestone's objective changes from no manual step to one approval
  per release.
- The approval is given by the account that tokens acting as the account
  impersonate. A stolen account token can approve a pending deployment
  until #1076, #1069, and #738 remove those tokens.
- Holding updates to actions shared by CI and release jobs also holds
  their CI updates. That adds Renovate pull requests to review.

Neutral:

- Remove the approval once alerts on unexpected releases exist and
  packages can be verified against their builds. Revisit the automerge
  rules if they bring too many pull requests.

## More Information

The bundling check per repository is on #1075. Environment approvals
land in #1121 and #1122, and the automerge rules in
`alunduil/renovate-config#49`.
