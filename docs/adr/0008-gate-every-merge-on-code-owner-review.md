<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Gate every merge on code-owner review

- Status: Proposed
- Date: 2026-11-28

## Context and Problem Statement

Every managed repository needs one rule for who may approve and merge a
pull request. Several forces shape it:

- The operator maintains most repositories alone, and GitHub doesn't let
  a pull request's author approve it. Any review requirement needs a
  bypass for the operator.
- Renovate has to merge its own green pull requests unattended, while
  required checks still bind it.
- Some repositories have write collaborators, who should be able to merge
  work a code owner approved.
- Agents work under the operator's login, so whatever lets the operator
  through lets them through too.
- GitHub's automatic merging doesn't apply Renovate's ruleset bypass, so
  it leaves Renovate's pull requests waiting for review (#1424). Renovate
  merges them with its own call on a later run.

## Considered Options

- **`admin-only` where write collaborators exist.** Only the admin and
  Renovate can update the default branch. Repositories end up with two
  gates, and a collaborator can't merge work a code owner approved.
- **A required approval check, with automatic merging.** The check passes
  on a verified Renovate commit or on the operator's approval of the
  head. A pull request can add its own job under the check's name, and
  nobody has tested whether GitHub accepts that copy. If it does, a
  collaborator can merge on a spoofed pass. All the check buys is faster
  Renovate merges, and Renovate's own merge is fast enough.
- **Code-owner review everywhere.** One gate, which a collaborator passes
  with a code owner's approval, and which the admin and Renovate bypass.

## Decision Outcome

Chosen option: **code-owner review everywhere.** Before a merge, every
managed repository requires a code owner to approve the last push, and
CODEOWNERS owns every path. The admin role bypasses the review, and
Renovate bypasses it only when merging a pull request. Required checks
bind everyone, and automatic merging stays off. Issue #709 applies this
across repositories.

Revisit this when agents get an account of their own (#1361), or if
GitHub's automatic merging starts applying ruleset bypasses.

### Consequences

- A contributor's pull request from a fork needs a code owner's approval,
  and a push after approval needs it again. The operator or an approved
  write collaborator merges it.
- Renovate merges its own pull requests once their checks pass, on its
  next run that doesn't push. In #1424's test that took about an hour.
- Agents under the operator's login share the admin bypass, and nothing
  tells their merges from the operator's.
- An agent with its own account fits best as a fork contributor. As a
  write collaborator it would still need approval to merge, but it would
  hold repository secrets and could create or delete Renovate's branches.
- A fast-releasing dependency often waits for the operator, because it
  rarely gets a Renovate run that doesn't push. `renovatebot/pre-commit-hooks`
  releases about 7 times a day. No Renovate setting fixes this: every
  hold setting returns before the merge step, and x.y.0 releases alone
  still come about twice a day (`alunduil/renovate-config#151`).
- Renovate is trusted outright, as the [Renovate path threat
  model](../explanation/threat-model-renovate.md) already accepts.
