<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Release path data flow

How a commit becomes a published package, and which credential carries it
across each trust boundary. The
[release path threat model](threat-model-release-path.md) walks these
elements.

Verified 2026-11-06.

## Scope

Written for the operator deciding where a new release credential belongs. It
assumes the [asset register](../reference/asset-register.md), whose IDs appear
here, and describes today's path. The App #556 plans appears only in the threat
model's comparison.

The diagrams cover the repositories that publish or plan to:

- `collection-json.hs`
- `network-arbitrary`
- `siren-json.hs`
- `woodland-generators`
- `zellij-claude-pair`
- `zfs-replicate`

Out of scope:

- What happens to a package after a registry accepts it.
- How a dependency reaches a pull request, apart from Renovate pushing it.
- Routes other repositories could add later. Issue #1077 keeps the inventory
  of what starts a release, and this page records what the workflows do at the
  verification date.

## Context

The system takes changes and release requests from people and automation, and
delivers packages to registries and to Foundry worlds.

```mermaid
flowchart LR
  contributor["Contributor"]
  writer["Write actor"]
  operator["Operator"]
  hackage["Hackage"]
  pypi["PyPI"]
  foundry["Foundry world"]
  system("0 Release a package")

  contributor -->|"F1 proposed commits"| system
  writer -->|"F2 pushed commits"| system
  operator -->|"F3 review decision"| system
  writer -->|"F9 tag request"| system
  operator -->|"F10 operator tag request"| system
  writer -->|"F14 dispatched ref"| system
  operator -->|"F15 operator dispatched ref"| system
  writer -->|"F25 replacement assets"| system
  system -->|"F19 Hackage upload"| hackage
  hackage -->|"F20 candidate tarball"| system
  system -->|"F21 PyPI publish request"| pypi
  pypi -->|"F22 PyPI upload token"| system
  system -->|"F27 manifest and zip"| foundry
```

The entities group principals that face the same threats:

| Entity | Principals |
| --- | --- |
| Contributor | Anyone opening a pull request, through E-04 |
| Write actor | P-5, P-6, P-7, and P-8 |
| Operator | P-1, and C-13 and C-32, which act as the account |
| Hackage | D-12 |
| PyPI | D-13 |
| Foundry world | Anyone installing the `woodland-generators` module |

## Level 0

The three trust boundaries are the repository, a job running the workflow
at a commit, and a job admitted to a deployment environment. A bracket on a flow
names the credential or permission that carries it. A flow with no bracket
stays inside one boundary or needs no credential.

```mermaid
flowchart LR
  contributor["Contributor"]
  writer["Write actor"]
  operator["Operator"]
  hackage["Hackage"]
  pypi["PyPI"]
  foundry["Foundry world"]

  subgraph repo["GitHub repository: rulesets decide who changes these"]
    merge("1.0 Merge pull request")
    tag("3.0 Create tag or Release")
    commits[("Repository commits")]
    releases[("Tags and Releases")]
    repo_secrets[("Repository secrets")]
    env_secrets[("Environment secrets")]
  end

  subgraph job["Actions job: runs what the commit's workflow says"]
    prepare("2.0 Prepare release")
    build("4.0 Build package")
    assets("6.0 Attach Release assets")
    artifacts[("Build artifacts")]
  end

  subgraph env["Environment job: the ref's name must match a tag pattern"]
    upload("5.0 Upload package")
  end

  contributor -->|"F1 proposed commits [account login]"| merge
  writer -->|"F2 pushed commits [Contents write]"| merge
  operator -->|"F3 review decision [admin role]"| merge
  merge -->|"F4 merged commit"| commits
  commits -->|"F5 merged history [C-32]"| prepare
  repo_secrets -->|"F6 account token [C-32]"| prepare
  prepare -->|"F7 release pull request [C-32]"| merge
  prepare -->|"F8 prepared tag request [C-32]"| tag
  writer -->|"F9 tag request [Contents write]"| tag
  operator -->|"F10 operator tag request [admin role]"| tag
  tag -->|"F11 tag and Release"| releases
  releases -->|"F12 release ref [none]"| build
  commits -->|"F13 source and workflow [P-11 read]"| build
  writer -->|"F14 dispatched ref [Actions write]"| build
  operator -->|"F15 operator dispatched ref [admin role]"| build
  build -->|"F16 package"| artifacts
  artifacts -->|"F17 built package [P-11 Actions read]"| upload
  env_secrets -->|"F18 Hackage token [environment tag rule]"| upload
  upload -->|"F19 Hackage upload [C-29, C-30]"| hackage
  hackage -->|"F20 candidate tarball [none]"| upload
  upload -->|"F21 PyPI publish request [P-11 id-token]"| pypi
  pypi -->|"F22 PyPI upload token [none]"| upload
  upload -->|"F23 release state [P-11 Contents write]"| releases
  build -->|"F24 module assets"| assets
  writer -->|"F25 replacement assets [Contents write]"| assets
  assets -->|"F26 stored assets [P-11 Contents write]"| releases
  assets -->|"F27 manifest and zip [none]"| foundry
```

Flows F5, F6, F7, F8, F12, F13, F17, F18, F23, and F26 cross between the
repository, a job, and an environment job. A job holds nothing until one of
these flows gives it something.

## How repositories differ

Each repository uses part of the diagram:

- `collection-json.hs`: `prereleased` uploads a candidate, and a dispatch on the
  tag publishes it to D-12. C-29 sits in the `hackage` environment, which admits
  `v*`.
- `network-arbitrary`: `published` publishes to D-12. C-30 sits in the `hackage`
  environment, which admits `v*`.
- `siren-json.hs`: nothing starts the path yet, because it has no `release.yml`.
  Its `hackage` environment admits any ref and holds no secret.
- `woodland-generators`: a push to `main` runs release-please with C-32. A later
  job attaches Release assets with P-11, and no environment is involved.
- `zellij-claude-pair`: nothing starts the path yet, because it has no release
  workflow.
- `zfs-replicate`: `published` publishes to D-13 through trusted publishing. Its
  `pypi` environment admits `v*.*.*`.

The operator created the latest Releases everywhere except `woodland-generators`,
where C-32 acts as the account.

The diagram draws processes rather than jobs, and three differences matter for
the threat model:

- `network-arbitrary` and `collection-json.hs`'s `candidate` job run 4.0 and
  5.0 in one job, so build code shares a job with the Hackage token.
- `woodland-generators` runs 4.0 and 6.0 in one job, so build code shares a job
  with `Contents` write.
- `zfs-replicate` runs 4.0 and 5.0 in separate jobs.

Only `collection-json.hs` refuses a tag that isn't on the default branch. That
check lives in the workflow at the tag, so it binds only an actor who can't
change workflow files.

Every Write actor can also use F9, and those holding `Actions` write can use
F14.
