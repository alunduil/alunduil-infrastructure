<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->
<!-- markdownlint-disable MD013 -- a table's rows can't wrap -->

# Gate every merge on code-owner review

- Status: Proposed
- Date: 2026-11-28

## Context and Problem Statement

Every managed repository needs one answer to who may approve and merge
a pull request. Until now that answer has been spread across seven
issues: #709, #888, #1057, #1282, #445, #1112 and #1361. It has been
reassessed several times. The live settings have drifted from it. A check on
2026-11-28 found:

- 9 of the 16 source repositories have no CODEOWNERS file, and their
  `review` ruleset requires no review: `agent-plugins`,
  `alunduil-chezmoi`, `collection-json.hs`, `git-worktree-poi`,
  `network-arbitrary`, `release-gate`, `renovate-config`,
  `siren-json.hs` and `vale-styles`.
- `admin-only` gates merges on `collection-json.hs`,
  `network-arbitrary`, `renovate-config` and `siren-json.hs`.
  `zfs-replicate` gates its write collaborators with code-owner review
  instead.
- GitHub's automatic merging (`allow_auto_merge`) is on for
  `zfs-replicate`, `renovate-config` (#1427), `genshin.dungeon.studio`
  and `qua-world`.

Automatic merging doesn't apply Renovate's ruleset bypass. #1424 tested
it on `zfs-replicate` after #1427 applied:

- On `zfs-replicate#955`, Renovate turned on automatic merging at
  15:50:52Z, and every required check had passed by 15:53:58Z. The pull
  request stayed waiting on code owner review.
- Renovate's own merge calls between 15:50 and 15:51 failed on `review`
  and `checks` (rule suite 5427874902).
- Renovate's own call merged it at 16:52:37Z, on its next run, with
  rule-suite result `bypass` (5428404709).

This matches what #888 found.

### Requirements

- **One gate.** One ruleset decides whether a person's merge needs
  review, the same way in every repository.
- **Renovate merges unattended.** A green Renovate pull request merges
  without the operator, and required checks still bind it.
- **Collaborators merge after review.** An approved write collaborator
  can merge without the admin (#1112).
- **Every merge path is known.** Each kind of actor has one stated way
  to approve and merge.

## Considered Options

- **Keep `admin-only` where write collaborators exist.** Only the admin
  and Renovate can update the default branch, so a collaborator can't
  merge even after approval. This fails the collaborator requirement,
  and it gives repositories two different gates.
- **Gate merges on code-owner review everywhere.** This meets all four
  requirements.
- **Let GitHub's automatic merging land Renovate's pull requests.** This
  fails the unattended Renovate requirement, because automatic merging
  never applies Renovate's bypass (#1424, #888).
- **Replace code-owner review with a required approval check, so
  automatic merging works.** The check would pass when every commit is a
  verified Renovate commit and Renovate turned on the merge, or when the
  operator approved the head. A pull request can add its own job under
  the check's name, and nobody has tested whether GitHub accepts that
  copy. If it does, a write collaborator can merge on a spoofed pass.
  Renovate's own merge, about an hour on `zfs-replicate#955`, is fast
  enough, so the check buys nothing worth that risk.

## Decision Outcome

Chosen option: **gate merges on code-owner review everywhere.**

Every managed repository applies these rulesets and settings:

- `review`: code-owner review, with `require_last_push_approval`
  (#1282). CODEOWNERS owns every path and is managed from Terraform.
  The admin role bypasses it with mode `always`, and Renovate
  (Integration 2740) with mode `pull_request`.
- No `admin-only` ruleset. Code-owner review is the one merge gate, and
  an approved write collaborator may merge (#1112).
- `checks`: required checks with no bypass.
- `renovate/**`: the `update` rule, which Renovate and the hook-fix App
  bypass. `check-renovate-commits` holds any other commit until the
  operator approves the head (#1057).
- `allow_auto_merge` is false.
- Collaborators are declared in Terraform (#445).

Under these rules, each kind of actor approves and merges like this:

| Actor | Approves | Merges | Notes |
| --- | --- | --- | --- |
| External contributor, from a fork | The code owner must | The operator, or a write collaborator after approval | A push after approval needs approval again |
| Renovate | Skips review through its bypass | Renovate, on its next run that doesn't push | Required checks still bind it. Hook-fix commits and held updates wait for the operator |
| Operator | Not needed | Through the admin bypass | |
| Agents under the operator's login | Not needed | Through the admin bypass | The policy doesn't separate them from the operator until #1361 |
| Agent identity, from a fork | As for an external contributor | As for an external contributor | Recommended default |
| Agent identity, as a write collaborator | The code owner must | After approval, with no bypass | Gains repository secrets in its branch workflows, and can create (#1281) or delete (#1269) Renovate branches |

`dungeon-studio` and `qua-world` adopt this policy and record only where
they differ. #709 applies it across repositories.

### Consequences

Good:

- One ruleset gates every person's merge, so a repository's access
  follows from its CODEOWNERS file and collaborator list.
- A write collaborator can land approved work without the operator.

Bad / accepted:

- Agents under the operator's login share the admin bypass until #1361.
- A fast-releasing dependency merges only on a Renovate run that doesn't
  push. `renovatebot/pre-commit-hooks` publishes about 7 releases a day,
  so its updates often wait for the operator
  (`alunduil/renovate-config#151`). No Renovate setting fixes this:
  - A daily update window can't help, so `alunduil/renovate-config#154`
    closed unmerged. Every Renovate hold setting returns before the
    merge step: `schedule` with `updateNotScheduled: false`,
    `rebaseWhen: never` and `stopUpdatingLabel`.
  - Taking only x.y.0 releases still leaves about 2 a day, 23 of the 81
    releases from 2026-11-16 to 2026-11-27, against 4–6 Renovate runs.
- Renovate is trusted outright, as the [Renovate path threat
  model](../explanation/threat-model-renovate.md) already accepts.
- These gaps stay open: #1281, #1269 and #429.

Neutral:

- Merging through Renovate's own call took about an hour on
  `zfs-replicate#955`, the time to Renovate's next run.

## More Information

The automatic-merging test evidence is on #1424. #709 applies the
rulesets and settings.
