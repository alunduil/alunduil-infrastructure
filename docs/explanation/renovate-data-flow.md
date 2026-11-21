<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Renovate path data flow

How a dependency update becomes a merged commit on a default branch, and
which credential carries it across each trust boundary. The [Renovate path
threat model](threat-model-renovate.md) walks these elements.

Verified 2026-11-21.

## Scope

Written for the operator deciding who may write to a Renovate branch or read
the hook-fix key. It assumes the [asset
register](../reference/asset-register.md), whose IDs appear here. The
self-test App #1159 plans appears only in the threat model.

The diagrams cover:

- Every repository with `renovate_automerge`, which gives Renovate its merge
  bypass and adds the `renovate` ruleset.
- `renovate-config`, whose default branch holds the shared preset and
  `fix-renovate-hooks.yml`.

Out of scope:

- What a merged commit reaches next. [Credential
  reachability](credential-reachability.md) follows `main` in this repository
  to `terraform apply`, and the [release path data
  flow](release-path-data-flow.md) follows a default branch to a registry.
- What Mend does inside Renovate.

## Context

The system takes dependency releases, branch writes, and review decisions,
and delivers merged commits to default branches.

```mermaid
flowchart LR
  source["Dependency source"]
  renovate["Renovate"]
  writer["Write actor"]
  operator["Operator"]
  system("0 Merge a dependency update")

  source -->|"F1 dependency release"| renovate
  system -->|"F2 shared preset"| renovate
  renovate -->|"F3 update commits"| system
  writer -->|"F4 created branch"| system
  renovate -->|"F16 merge request"| system
  operator -->|"F17 review decision"| system
  writer -->|"F19 renovate-config change"| system
  operator -->|"F20 operator preset change"| system
```

The entities group principals that face the same threats:

| Entity | Principals |
| --- | --- |
| Dependency source | Registries and upstream repositories |
| Renovate | P-6 |
| Write actor | P-7 and P-8 |
| Operator | P-1 |

## Level 0

The six trust boundaries are:

- `renovate-config`, whose default branch every repository reads.
- A calling repository, whose rulesets decide who changes its branches.
- A pull request job, which runs the branch's code.
- The hooks job, which runs the update's hook code and holds no secret.
- The push job, which holds C-25.
- Google Cloud, where the provider's condition decides who reads the key.

A bracket on a flow names the credential or permission that carries it. A
flow with no bracket stays inside one boundary or needs no credential.

```mermaid
flowchart LR
  source["Dependency source"]
  renovate["Renovate"]
  writer["Write actor"]
  operator["Operator"]

  subgraph config["renovate-config: every repository reads its default branch"]
    config_commits[("renovate-config commits")]
  end

  subgraph repo["Calling repository: rulesets decide who changes these"]
    branches[("Renovate branches")]
    default[("Default branch")]
    merge("5.0 Merge pull request")
  end

  subgraph ci["Pull request job: runs the branch's code"]
    checks("1.0 Run checks")
  end

  subgraph hooks["Hooks job: runs the update's hook code, holds no secret"]
    run_hooks("2.0 Run hooks")
    artifact[("Fix artifact")]
  end

  subgraph push["Push job: holds C-25"]
    push_fixes("3.0 Push hook fixes")
  end

  subgraph gcp["Google Cloud: the provider's condition decides who reads"]
    admit("4.0 Admit workflow")
    secrets[("Hook-fix secrets")]
  end

  source -->|"F1 dependency release [none]"| renovate
  config_commits -->|"F2 shared preset [P-6 read]"| renovate
  renovate -->|"F3 update commits [P-6 Contents write, renovate bypass]"| branches
  writer -->|"F4 created branch [Contents write]"| branches
  branches -->|"F5 branch code [P-11 read]"| checks
  checks -->|"F6 check results"| merge
  branches -->|"F7 hook input [P-11 read]"| run_hooks
  config_commits -->|"F8 hooks workflow [none]"| run_hooks
  config_commits -->|"F9 push workflow [none]"| push_fixes
  run_hooks -->|"F10 fix diff"| artifact
  artifact -->|"F11 stored diff [P-11 Actions read]"| push_fixes
  push_fixes -->|"F12 OIDC token [P-11 id-token]"| admit
  admit -->|"F13 reader token [none]"| push_fixes
  secrets -->|"F14 App ID and key [hook-fix-reader]"| push_fixes
  push_fixes -->|"F15 fix commit [C-25, renovate bypass]"| branches
  renovate -->|"F16 merge request [P-6 pull_request bypass]"| merge
  operator -->|"F17 review decision [admin role]"| merge
  merge -->|"F18 merged commit"| default
  writer -->|"F19 renovate-config change [Contents and Workflows write]"| config_commits
  operator -->|"F20 operator preset change [admin role]"| config_commits
```

Flows F2, F5, F7, F8, F9, F11, F12, F13, F14, F15, and F19 cross a boundary.
A job holds nothing until one of these flows gives it something.

A merge in `renovate-config` is also 5.0, with `renovate-config commits` as
its default branch. F19 and F20 draw it as a direct change, because that
repository has no `admin-only` ruleset and its `review` ruleset requires no
approval.

## How repositories differ

Each repository uses part of the diagram:

- Eleven repositories set `renovate_automerge`: `alunduil-chezmoi`,
  `alunduil-infrastructure`, `blog.alunduil.com`, `collection-json.hs`,
  `git-worktree-poi`, `network-arbitrary`, `projects-v2-sync`,
  `siren-json.hs`, `woodland-generators`, `zellij-claude-pair`, and
  `zfs-replicate`. The others have no `renovate` ruleset and no merge bypass
  for Renovate, so the operator merges their updates.
- Four call `fix-renovate-hooks.yml`: `alunduil-infrastructure`,
  `projects-v2-sync`, `woodland-generators`, and `zfs-replicate`. Each pins it
  by commit with a `# main` comment and extends `:automergeDigest`, so a new
  `renovate-config` commit reaches them as an automerging digest update. The
  rest skip 2.0 through 4.0.
- `zfs-replicate` has twelve write collaborators. Every other repository here
  has only the operator, so its Write actor is P-8 alone.
- `renovate-config` neither sets `renovate_automerge` nor calls the
  workflow. #1038 plans both.

The hook-fix App's token covers only the calling repository, because the push
job names no other. Its key isn't limited that way: C-25 is installed on
every repository.
