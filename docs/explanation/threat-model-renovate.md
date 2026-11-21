<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->
<!-- markdownlint-disable MD013 -- a threat table's rows can't wrap -->

# Renovate path threat model

What can go wrong between a dependency release and a merged commit on a
default branch, and what the self-test App #1159 may hold. Hook fixes and
automerge both put commits on a default branch with nobody looking, so this
model weighs who can write to a Renovate branch above everything else.

Verified 2026-11-21.

## Scope

Written for the operator deciding who may write to a Renovate branch or read
the hook-fix key. It walks every element of the [Renovate path data
flow](renovate-data-flow.md) using STRIDE, and assumes the [asset
register](../reference/asset-register.md) and [credential
reachability](credential-reachability.md).

The rows come from reading configuration, workflows, and the documentation of
GitHub and Renovate. [Release control
behaviour](../reference/release-control-behaviour.md) records the Renovate and
commit-signing behaviour the rows rely on. Nobody has tried an attack against
a managed repository.

Out of scope:

- What a merged commit reaches next, which credential reachability and the
  [release path threat model](threat-model-release-path.md) cover.
- P-1's own compromise. #1066 covers the workstation.
- Compromise of GitHub, Mend, or Anthropic. [Credential
  reachability](credential-reachability.md#why-renovate-and-the-claude-app-are-accepted)
  explains why Mend and Anthropic are accepted.

## Where the self-test App fits

The self-test (`renovate-config#23`) opens `renovate/hook-fix-selftest-*` pull
requests in `renovate-config` and checks what `fix-renovate-hooks.yml` does
with them. It needs its own App, because events from `GITHUB_TOKEN` start no
workflow and the hook-fix workflow skips the hook-fix App's own events.

The App's design follows:

- **Permissions:** `Contents` and `Pull requests` write, without `Workflows`.
  `Workflows` write on `renovate-config` would let a leaked key push a changed
  `fix-renovate-hooks.yml` to a branch. The hook-fix provider admits any
  commit of that file, so the key would then read C-25 and reach every
  repository. The self-test case that plants a fault under
  `.github/workflows/` tests a guard that `renovate-config#24` can cover with
  bats instead.
- **Installation:** `renovate-config` only.
- **Its own provider:** an exact match on
  `alunduil/renovate-config/.github/workflows/hook-fix-selftest.yml@refs/heads/main`.
  The self-test is a top-level workflow, so unlike the hook-fix workflow its
  `job_workflow_ref` names a branch rather than the caller's pinned commit,
  and a prefix match would admit any branch.
- **The hook-fix provider:** once #1267 limits it to runs Renovate starts, it
  also admits the self-test App's runs, in `renovate-config` only.
- **The default branch:** #1268 lands first. With `Pull requests` write and
  no `admin-only` ruleset, the key could merge its own pull request into the
  branch every repository's Renovate policy comes from.

The draft App in #1160 has `Workflows` write and a prefix match, so both need
to change before it merges.

## Findings

Every unmitigated row below points to one of these.

| Finding | Issue |
| --- | --- |
| Hook-fix commits reach a default branch unreviewed | #1057 |
| Any alunduil run of any commit of the hook-fix workflow can read C-25 | #1267 |
| Anyone able to merge in `renovate-config` changes every repository's Renovate policy | #1268 |
| A re-pointed third-party tag automerges with no wait | `renovate-config#82` |
| Hook fixes can edit composite actions | `renovate-config#39` |
| A write actor can delete a Renovate branch, which drops its update | #1269 |
| Updated code in a pull request job reaches CI plan's credentials | #1063 |
| A required check can be satisfied by any App reporting its name | #429 |
| A hooks job can write a cache a later run restores | #1079 |

## Threats

Priority ranks what the operator would stop to fix. In the Evidence column,
`main.tf` is `terraform/modules/github_repository/main.tf`, `hook_fix.tf` is
`terraform/bootstrap/hook_fix.tf`, `register` is
`docs/reference/asset-register.md`, `behaviour` is
`docs/reference/release-control-behaviour.md`, and `workflow` and
`default.json` are `.github/workflows/fix-renovate-hooks.yml` and
`default.json` in `renovate-config`.

### Context

| Element | Category | Threat | Priority | Mitigation | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 0 Merge a dependency update | All | Analysed through its decomposition at Level 0 | — | — | Not Applicable | `renovate-data-flow.md`, Level 0 |

### Level 0

| Element | Category | Threat | Priority | Mitigation | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Dependency source | Spoofing | A stolen maintainer or registry account publishes a release under the real name | High | `minimumReleaseAge` holds a new release three days. `renovate-config#82` for re-pointed tags | Not Started | `default.json`, `minimumReleaseAge` |
| Dependency source | Repudiation | A registry's record is the only one of who published a version | Low | Each Renovate pull request records the version and digest it took | Mitigated | register, D-09 |
| Renovate | Spoofing | Another actor claims Renovate's ruleset bypass | High | Rulesets name the App by its ID | Mitigated | `main.tf`, `local.renovate_actor` |
| Renovate | Repudiation | Renovate denies a commit or merge | — | — | Not Applicable | behaviour, Bot commit signing. GitHub signs Renovate's API commits and records the merger |
| Write actor | Spoofing | A stolen collaborator account, or a prompted Claude App session, runs its own copy of the hook-fix workflow and reads C-25 | High | #1267 | Not Started | `hook_fix.tf`, `attribute_condition` |
| Write actor | Repudiation | A write actor creates a `renovate/**` branch, and the hook-fix App commits to it in the App's name | Low | #1267 refuses runs Renovate didn't start | Not Started | `main.tf`, `github_repository_ruleset.renovate` sets only `update` |
| Operator | Spoofing | A stolen operator session merges or edits the preset | — | — | Not Applicable | Out of scope, #1066 |
| Operator | Repudiation | The operator denies a change made with their own session | — | — | Not Applicable | register, P-1 |
| 1.0 Run checks | Spoofing | An App reporting a required check's name satisfies it | Medium | #429 | Not Started | `main.tf`, `github_repository_ruleset.checks` |
| 1.0 Run checks | Tampering | An updated action or hook changes the check it runs in, so it passes itself | Medium | `minimumReleaseAge`, and `renovate-config#82` for re-pointed tags | Not Started | `default.json`, `minimumReleaseAge` |
| 1.0 Run checks | Repudiation | Run logs record each check, and a merged update stays in history | — | — | Not Applicable | register, D-09 |
| 1.0 Run checks | Information Disclosure | Updated code reads the secrets its pull request job holds | High | #1063 | Not Started | `credential-reachability.md`, What CI holds |
| 1.0 Run checks | Denial of Service | A check that never reports holds the merge for the operator | — | — | Not Applicable | `terraform/modules/github_repository/variables.tf`, `required_status_checks` |
| 1.0 Run checks | Elevation of Privilege | Updated code acts with CI plan's credentials before anyone reviews it | High | #1063 | Not Started | `.github/workflows/terraform-plan.yml`, `on.pull_request` |
| 2.0 Run hooks | Spoofing | A fork's pull request feeds the push | High | The job runs only when the head repository is the base | Mitigated | workflow, job `hooks`, `if` |
| 2.0 Run hooks | Tampering | Hook code writes any in-place edit into the diff, which the push job commits | High | #1057, `renovate-config#39` | Not Started | workflow, step `Capture fixes` |
| 2.0 Run hooks | Repudiation | Nothing ties a fix to the hook that made it once the run log expires | Low | #1057 has the operator review each fix | Not Started | workflow, step `Run hooks` |
| 2.0 Run hooks | Information Disclosure | Hook code reads a credential | Medium | The job holds no secret or `id-token`, and its read-only token isn't persisted | Mitigated | workflow, job `hooks`, `persist-credentials: false` |
| 2.0 Run hooks | Denial of Service | A hook loops or hangs | Low | A 15-minute timeout, and the hook-fix App's own pushes skip the job | Mitigated | workflow, job `hooks` |
| 2.0 Run hooks | Elevation of Privilege | Hook code writes a cache that a later, more trusted run restores | Medium | #1079 | Not Started | workflow, step `Install Node`, `cache: pnpm` |
| 3.0 Push hook fixes | Spoofing | A run Renovate didn't start pushes as C-25 | High | #1267 | Not Started | `hook_fix.tf`, `attribute_condition` |
| 3.0 Push hook fixes | Tampering | The diff adds, deletes, or re-types a file, moves a submodule, or edits a workflow | High | The job refuses each of these | Mitigated | workflow, steps `Reject fixes that aren't in-place edits` and `Reject fixes to workflow files` |
| 3.0 Push hook fixes | Tampering | The diff edits a composite action, which a workflow then runs | High | `renovate-config#39` | Not Started | workflow, step `Reject fixes to workflow files` checks only `.github/workflows` |
| 3.0 Push hook fixes | Repudiation | Hook-fix commits are pushed with git, so GitHub doesn't sign them, and Renovate compares only the author email | Medium | #1057 | Not Started | behaviour, Modified-branch detection |
| 3.0 Push hook fixes | Information Disclosure | Code from the checkout reads the key | High | The job runs pinned actions and `git`, and nothing from the checkout | Mitigated | workflow, job `push` |
| 3.0 Push hook fixes | Denial of Service | A branch moves while the push job runs | — | — | Not Applicable | workflow, step `Push fixes` skips a moved branch, and the newer run fixes it |
| 3.0 Push hook fixes | Elevation of Privilege | Whoever chooses the workflow's commit chooses what the job does with C-25 | High | #1267, `renovate-config#21` | Not Started | `hook_fix.tf`, comment on `attribute_condition` |
| 4.0 Admit workflow | Spoofing | A token from a fork-only commit, or from a `renovate-config` branch, passes the prefix match | High | #1267 | Not Started | `hook_fix.tf`, `attribute_condition` |
| 4.0 Admit workflow | Tampering | Changing the condition needs the bootstrap layer, which only the operator applies | — | — | Not Applicable | `docs/how-to/bootstrap.md` |
| 4.0 Admit workflow | Repudiation | Every admitted run acts as `hook-fix-reader`, so an unexpected read looks like an expected one | Medium | #1267 narrows who is admitted | Not Started | `terraform/alunduil/gcp_observability.tf`, `Unexpected Data Access` |
| 4.0 Admit workflow | Information Disclosure | The condition admits any alunduil repository, event, and actor | High | #1267 | Not Started | `hook_fix.tf`, `attribute_condition` |
| 4.0 Admit workflow | Denial of Service | A Google Cloud outage stops fixes, and the pull request waits | — | — | Not Applicable | workflow, job `push` |
| 4.0 Admit workflow | Elevation of Privilege | The reader gains more than the App's two secrets | Medium | The reader holds no project role, only accessor on those secrets | Mitigated | `hook_fix.tf`, `hook_fix_app_reader` |
| 5.0 Merge pull request | Spoofing | GitHub accepts a merge from whoever holds a bypass, which the Renovate and Operator rows cover | — | — | Not Applicable | `main.tf`, `local.merge_bypass_actors` |
| 5.0 Merge pull request | Tampering | A hook-fix commit lands on a default branch unreviewed | High | #1057 | Not Started | `main.tf`, `github_repository_ruleset.renovate` |
| 5.0 Merge pull request | Tampering | A compromised update automerges once its checks pass | High | `minimumReleaseAge`, release-job holds, and `renovate-config#82` | Not Started | `default.json`, `packageRules` |
| 5.0 Merge pull request | Repudiation | GitHub records the merger and the merged head on the pull request | — | — | Not Applicable | register, D-09 |
| 5.0 Merge pull request | Information Disclosure | Every repository here is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| 5.0 Merge pull request | Denial of Service | A failing check holds the update for the operator, which is the rule working | — | — | Not Applicable | `main.tf`, `github_repository_ruleset.checks` |
| 5.0 Merge pull request | Elevation of Privilege | Renovate merges past `review` and `admin-only` with only required checks binding it | Medium | Required checks, and the accepted trust in Mend | Mitigated | `credential-reachability.md`, Why Renovate and the Claude App are accepted |
| Shared config commits | Tampering | Anyone able to merge here changes every repository's automerge policy and hook-fix workflow | High | #1268 | Not Started | `terraform/alunduil/repositories.tf`, `renovate-config` sets no `admin_only_updates` |
| Shared config commits | Tampering | A branch's copy of the hook-fix workflow reads C-25 | High | #1267 | Not Started | `hook_fix.tf`, `attribute_condition` |
| Shared config commits | Repudiation | A pushed commit's author is free text | Low | #1268 limits who updates the default branch | Not Started | behaviour, Bot commit signing |
| Shared config commits | Information Disclosure | The preset and workflow are public by design | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| Shared config commits | Denial of Service | Someone deletes or rewrites the default branch, which every caller's preset reads | Medium | `default` blocks deletion and force pushes | Mitigated | `main.tf`, `github_repository_ruleset.default` |
| Renovate branches | Tampering | Someone other than Renovate or the hook-fix App adds a commit | High | The `renovate` ruleset | Mitigated | `main.tf`, `github_repository_ruleset.renovate` |
| Renovate branches | Repudiation | Renovate counts a commit as its own when the author email matches `gitIgnoredAuthors` | Medium | #1057 | Not Started | behaviour, Modified-branch detection |
| Renovate branches | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| Renovate branches | Denial of Service | A write actor deletes a branch, which closes its pull request, and Renovate then skips that update | Medium | #1269 | Not Started | `main.tf`, `github_repository_ruleset.renovate` sets only `update` |
| Default branch | Tampering | Someone rewrites the default branch | High | `default` blocks force pushes | Mitigated | `main.tf`, `github_repository_ruleset.default` |
| Default branch | Repudiation | GitHub records each merge on its pull request | — | — | Not Applicable | register, D-09 |
| Default branch | Information Disclosure | The default branch is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| Default branch | Denial of Service | Someone deletes the default branch | Medium | `default` blocks deletion | Mitigated | `main.tf`, `github_repository_ruleset.default` |
| Fix artifact | Tampering | Hook code writes the diff, so the artifact is as untrusted as the hooks | High | The push job's checks, and #1057 | Not Started | workflow, step `Capture fixes` |
| Fix artifact | Repudiation | The artifact expires after a day | Low | The fix commit and the run log outlast it | Mitigated | workflow, step `Upload fixes`, `retention-days: 1` |
| Fix artifact | Information Disclosure | The diff holds only source from a public repository | — | — | Not Applicable | workflow, step `Capture fixes` |
| Fix artifact | Denial of Service | A missing artifact fails the push, and the branch keeps Renovate's commit | — | — | Not Applicable | workflow, step `Download fixes` |
| Hook-fix secrets | Tampering | Adding a version needs project IAM, which reaches everything anyway | — | — | Not Applicable | `scripts/configure-hook-fix-secrets.sh` |
| Hook-fix secrets | Repudiation | Every read is logged as `hook-fix-reader`, whichever run made it | Medium | #1267 narrows who reads | Not Started | `terraform/alunduil/gcp_observability.tf`, `Unexpected Data Access` |
| Hook-fix secrets | Information Disclosure | Any admitted run reads the key | High | #1267 | Not Started | `hook_fix.tf`, `hook_fix_app_reader` |
| Hook-fix secrets | Denial of Service | A deleted or disabled version stops fixes, and pull requests wait | — | — | Not Applicable | workflow, step `Read App credentials` |
| F1 dependency release | Tampering | A re-pointed tag arrives as a digest update, which skips the release-age wait and automerges | High | `renovate-config#82` | Not Started | `default.json`, `packageRules`, and behaviour, Re-pointed tags behind digest pins |
| F1 dependency release | Information Disclosure | Releases are public | — | — | Not Applicable | register, P-6 |
| F1 dependency release | Denial of Service | A registry outage delays an update and loses nothing | — | — | Not Applicable | register, P-6 |
| F2 shared preset | Tampering | Renovate reads the preset from the default branch on each run, unpinned | High | #1268 | Not Started | `renovate.json`, `extends` in each repository |
| F2 shared preset | Information Disclosure | The preset is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F2 shared preset | Denial of Service | A broken preset stops Renovate in every repository | Medium | `renovate-config-validator` runs before every merge | Mitigated | `renovate-config`'s `.pre-commit-config.yaml` |
| F3 update commits | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub or Mend | — | — | Not Applicable | register, D-09 |
| F3 update commits | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F3 update commits | Denial of Service | A Mend outage delays updates and loses nothing | — | — | Not Applicable | register, P-6 |
| F4 created branch | Tampering | A write actor creates a `renovate/**` branch, which the ruleset doesn't block, and hook-fix runs on its pull request | Low | #1267 | Not Started | `main.tf`, `github_repository_ruleset.renovate` sets only `update` |
| F4 created branch | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F4 created branch | Denial of Service | A flood of branches uses runner minutes on a public repository and merges nothing | — | — | Not Applicable | workflow, job `hooks` |
| F5 branch code | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F5 branch code | Information Disclosure | The branch is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F5 branch code | Denial of Service | A GitHub outage delays the merge and loses nothing | — | — | Not Applicable | register, D-09 |
| F6 check results | Tampering | An App reports a result under a required check's name | Medium | #429 | Not Started | `main.tf`, `github_repository_ruleset.checks` |
| F6 check results | Information Disclosure | Check results are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F6 check results | Denial of Service | Codecov leaves a check in progress, which holds the merge | — | — | Not Applicable | `terraform/modules/github_repository/variables.tf`, `codecov_project_check` |
| F7 hook input | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F7 hook input | Information Disclosure | The branch is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F7 hook input | Denial of Service | A GitHub outage delays the fix and loses nothing | — | — | Not Applicable | register, D-09 |
| F8 hooks workflow | Tampering | A new `renovate-config` commit reaches callers as an automerging digest update | Medium | #1268, `renovate-config#21` | Not Started | `.github/workflows/ci.yml`, `uses` and `# main` in each calling repository |
| F8 hooks workflow | Information Disclosure | The workflow is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F8 hooks workflow | Denial of Service | A broken workflow stops fixes, and Renovate's commit still runs its checks | — | — | Not Applicable | `alunduil-infrastructure`'s `.github/workflows/ci.yml`, job `fix-renovate-hooks` isn't required |
| F9 push workflow | Tampering | The caller chooses the commit, so a branch or fork commit's copy gets the key | High | #1267 | Not Started | `hook_fix.tf`, `attribute_condition` |
| F9 push workflow | Information Disclosure | The workflow is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F9 push workflow | Denial of Service | A broken workflow stops fixes, and Renovate's commit still runs its checks | — | — | Not Applicable | `alunduil-infrastructure`'s `.github/workflows/ci.yml`, job `fix-renovate-hooks` isn't required |
| F10 fix diff | Tampering | Hook code chooses the diff | High | The push job's checks, and #1057 | Not Started | workflow, step `Capture fixes` |
| F10 fix diff | Information Disclosure | The diff holds only public source | — | — | Not Applicable | workflow, step `Capture fixes` |
| F10 fix diff | Denial of Service | A failed upload stops the push, and the branch keeps Renovate's commit | — | — | Not Applicable | workflow, step `Upload fixes`, `if-no-files-found: error` |
| F11 stored diff | Tampering | Stays inside GitHub, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F11 stored diff | Information Disclosure | The diff holds only public source | — | — | Not Applicable | workflow, step `Download fixes` |
| F11 stored diff | Denial of Service | A failed download stops the push, and the branch keeps Renovate's commit | — | — | Not Applicable | workflow, step `Download fixes` |
| F12 OIDC token | Tampering | GitHub signs the token, so changing it invalidates it | — | — | Not Applicable | `hook_fix.tf`, `oidc.issuer_uri` |
| F12 OIDC token | Information Disclosure | The token is worth only what the provider's condition admits, which 4.0 covers | — | — | Not Applicable | `hook_fix.tf`, `attribute_condition` |
| F12 OIDC token | Denial of Service | A GitHub outage stops fixes and loses nothing | — | — | Not Applicable | register, D-09 |
| F13 reader token | Tampering | Google Cloud carries this over TLS, so tampering needs a compromise of Google | — | — | Not Applicable | workflow, step `Authenticate to Google Cloud` |
| F13 reader token | Information Disclosure | The token reaches only the job's steps | Low | The job runs pinned actions and `git`, and nothing from the checkout | Mitigated | workflow, job `push` |
| F13 reader token | Denial of Service | A Google Cloud outage stops fixes and loses nothing | — | — | Not Applicable | workflow, job `push` |
| F14 App ID and key | Tampering | Google Cloud carries this over TLS, so tampering needs a compromise of Google | — | — | Not Applicable | workflow, step `Read App credentials` |
| F14 App ID and key | Information Disclosure | The key sits in step outputs while later steps run | Medium | The later steps run pinned actions and `git`, and nothing from the checkout | Mitigated | workflow, job `push` |
| F14 App ID and key | Denial of Service | A failed read stops fixes and loses nothing | — | — | Not Applicable | workflow, step `Read App credentials` |
| F15 fix commit | Tampering | The commit carries hook output nobody reviewed | High | #1057 | Not Started | workflow, step `Push fixes` |
| F15 fix commit | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F15 fix commit | Denial of Service | A rejected push leaves the branch as Renovate wrote it | — | — | Not Applicable | workflow, step `Push fixes` |
| F16 merge request | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub or Mend | — | — | Not Applicable | register, D-09 |
| F16 merge request | Information Disclosure | Merges are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F16 merge request | Denial of Service | A Mend outage delays the merge and loses nothing | — | — | Not Applicable | register, P-6 |
| F17 review decision | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F17 review decision | Information Disclosure | Reviews are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F17 review decision | Denial of Service | A held update waits for the operator, which is the hold working | — | — | Not Applicable | `default.json`, `reviewers` |
| F18 merged commit | Tampering | Stays inside GitHub, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F18 merged commit | Information Disclosure | The default branch is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F18 merged commit | Denial of Service | A GitHub outage delays the merge and loses nothing | — | — | Not Applicable | register, D-09 |
| F19 shared config change | Tampering | A Claude App session or collaborator pushes a workflow branch that reads C-25, or merges a preset change | High | #1267, #1268 | Not Started | register, P-8 holds `workflows` write |
| F19 shared config change | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F19 shared config change | Denial of Service | A broken preset stops Renovate in every repository | Medium | `renovate-config-validator` runs before every merge | Mitigated | `renovate-config`'s `.pre-commit-config.yaml` |
| F20 operator preset change | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F20 operator preset change | Information Disclosure | The preset is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F20 operator preset change | Denial of Service | A broken preset stops Renovate in every repository | Medium | `renovate-config-validator` runs before every merge | Mitigated | `renovate-config`'s `.pre-commit-config.yaml` |
