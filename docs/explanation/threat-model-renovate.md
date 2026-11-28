<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->
<!-- markdownlint-disable MD013 -- a threat table's rows can't wrap -->

# Renovate path threat model

What can go wrong between a dependency release and a merged commit on a
default branch, and which permissions the self-test App (#1159) may hold.
Hook fixes and automerge both put commits on a default branch with nobody
looking, so this model weighs who can write to a Renovate branch above
everything else.

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
- Which secrets pull request jobs hold outside `alunduil-infrastructure`.
  Nobody has listed them.
- P-1's own compromise. #1066 covers the workstation.
- Compromise of GitHub, Mend, or Anthropic. [Credential
  reachability](credential-reachability.md#why-renovate-and-the-claude-app-are-accepted)
  explains why Mend and Anthropic are accepted.

## Where the self-test App fits

The self-test (`renovate-config#23`) opens `renovate/hook-fix-selftest-*` pull
requests in `renovate-config` and checks what `fix-renovate-hooks.yml` does
with them. It needs its own App, because events from `GITHUB_TOKEN` start no
workflow and the hook-fix workflow skips the hook-fix App's own events.

The App needs:

- **Permissions:** `Contents` and `Pull requests` write, without `Workflows`.
  `Workflows` write would let a leaked key push a changed
  `fix-renovate-hooks.yml` to a branch and run it with C-25. The self-test case
  that plants a fault under `.github/workflows/` tests a guard that
  `renovate-config#24` can cover with bats instead.
- **Installation:** `renovate-config` only.
- **Its own provider:** a prefix match on `hook-fix-selftest.yml` in
  `renovate-config`. The self-test runs on pull requests, so its provider has
  to admit any branch's copy. The key lacks `Workflows`, and `admin-only` keeps
  it off the default branch, so it adds nothing beyond opening pull requests
  and pushing branches in `renovate-config`.
- **The hook-fix provider:** admits Renovate's runs and, as an exception, the
  self-test App's in `renovate-config`.
- **The default branch:** `admin-only` stops the key merging its own pull
  request there.
- **Its own branches:** the `renovate` ruleset in `renovate-config` excludes
  `renovate/hook-fix-selftest-*`, so the App can commit planted faults there.
  The App has no bypass, so it can't push to a branch Renovate opened. Anyone
  with write access can update the self-test branches too, but Renovate never
  opens them, so nothing on them merges unreviewed.

A key with `Contents` write can still create a self-test branch at any commit
already in `renovate-config`. The self-test exception then admits that
commit's copy of the hook-fix workflow. Nobody has checked whether GitHub
refuses such a branch without `Workflows` when its workflow files differ from
the default branch's. #1289 checks. If GitHub allows it, the key can point a
branch at a commit P-8 pushed, and that commit's copy of the workflow reads
C-25.

## Findings

Each unmitigated row cites one of these issues.

| Finding | Issue |
| --- | --- |
| Hook-fix commits reach a default branch unreviewed | #1057 |
| A re-pointed third-party tag automerges with no wait | `renovate-config#82` |
| Hook fixes can edit composite actions | `renovate-config#39` |
| A write actor can delete a Renovate branch, which drops its update | #1269 |
| A write actor can create a Renovate branch before Renovate does | #1281 |
| A push after Code Owner approval merges unreviewed | #1282 |
| Updated code in a pull request job reaches CI plan's credentials | #1063 |
| A required check can be satisfied by any App reporting its name | #429 |
| A self-test run can call a branch's own copy of the hook-fix workflow | #1289 |

## Threats

Priority ranks what the operator would stop to fix. The Evidence column
shortens these sources:

- `main.tf`: `terraform/modules/github_repository/main.tf`
- `repositories.tf`: `terraform/alunduil/repositories.tf`
- `hook_fix.tf`: `terraform/bootstrap/hook_fix.tf`
- `secret_reader.tf`: `terraform/modules/workflow_secret_reader/main.tf`
- `register`: `docs/reference/asset-register.md`
- `behaviour`: `docs/reference/release-control-behaviour.md`
- `workflow`: `.github/workflows/fix-renovate-hooks.yml` in `renovate-config`
- `default.json`: `default.json` in `renovate-config`

### Context

| Element | Category | Threat | Priority | Mitigation | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 0 Merge a dependency update | All | Analysed through its decomposition at Level 0 | — | — | Not Applicable | `renovate-data-flow.md`, Level 0 |

### Level 0

| Element | Category | Threat | Priority | Mitigation | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Dependency source | Spoofing | A stolen maintainer or registry account publishes a release under the real name | High | `minimumReleaseAge` holds a new release three days. `renovate-config#82` for re-pointed tags | Not Started | `default.json`, `minimumReleaseAge` |
| Dependency source | Repudiation | A registry's record is the only one of who published a version | Low | Each Renovate pull request records the version and digest it took | Mitigated | register, D-09 |
| Write actor | Spoofing | A stolen collaborator account, or a prompted Claude App session, runs its own copy of the hook-fix workflow and reads C-25 | High | The provider admits only pull request runs by Renovate, or by the self-test App in `renovate-config` | Mitigated | `hook_fix.tf`, `extra_conditions` |
| Write actor | Repudiation | A write actor creates a `renovate/**` branch, and the hook-fix App commits to it in the App's name | Low | The provider refuses the write actor's runs. #1281 for a pull request Renovate opens from that branch | Not Started | `main.tf`, `github_repository_ruleset.renovate` sets only `update` |
| Operator | Spoofing | A stolen operator session merges or edits the preset | — | — | Not Applicable | Out of scope, #1066 |
| Operator | Repudiation | The operator denies a change made with their own session | — | — | Not Applicable | register, P-1 |
| 1.0 Propose update | Spoofing | Another actor claims Renovate's ruleset bypass | High | Rulesets name the App by its ID | Mitigated | `main.tf`, `local.renovate_actor` |
| 1.0 Propose update | Tampering | Mend changes what Renovate proposes | — | — | Not Applicable | `credential-reachability.md`, Why Renovate and the Claude App are accepted |
| 1.0 Propose update | Repudiation | Renovate denies a commit or merge | — | — | Not Applicable | behaviour, Bot commit signing. Renovate's commits on `renovate/**` branches report `verified: true` |
| 1.0 Propose update | Information Disclosure | Renovate reads only public repositories here | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| 1.0 Propose update | Denial of Service | A Mend outage delays updates and loses nothing | — | — | Not Applicable | register, P-6 |
| 1.0 Propose update | Elevation of Privilege | Renovate merges past `review` and `admin-only` with no required check binding it | Medium | The accepted trust in Mend | Mitigated | `credential-reachability.md`, Why Renovate and the Claude App are accepted |
| 2.0 Accept push | Spoofing | Another actor claims the hook-fix App's bypass | High | Rulesets name the App by its ID | Mitigated | `main.tf`, `local.hook_fix_actor` |
| 2.0 Accept push | Tampering | Someone other than Renovate or the hook-fix App adds a commit to a Renovate branch | High | The `renovate` ruleset | Mitigated | `main.tf`, `github_repository_ruleset.renovate` |
| 2.0 Accept push | Repudiation | A pushed commit's author is free text | Medium | #1057 checks for Renovate's signed commits | Not Started | behaviour, Bot commit signing |
| 2.0 Accept push | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| 2.0 Accept push | Denial of Service | A write actor deletes a Renovate branch, which closes its pull request, and Renovate then skips that update | Medium | #1269 | Not Started | `main.tf`, `github_repository_ruleset.renovate` sets only `update` |
| 2.0 Accept push | Elevation of Privilege | A write actor creates a `renovate/**` branch, which the ruleset doesn't block, and the hook-fix workflow runs on its pull request | Medium | The provider refuses the write actor's runs. #1281 for a pull request Renovate opens from that branch | Not Started | `main.tf`, `github_repository_ruleset.renovate` sets only `update` |
| 3.0 Run checks | Spoofing | An App reporting a required check's name satisfies it | Medium | #429 | Not Started | `main.tf`, `github_repository_ruleset.checks` |
| 3.0 Run checks | Tampering | An updated action or hook changes the check it runs in, so it passes itself | Medium | `minimumReleaseAge`, and `renovate-config#82` for re-pointed tags | Not Started | `default.json`, `minimumReleaseAge` |
| 3.0 Run checks | Repudiation | Run logs record each check, and a merged update stays in history | — | — | Not Applicable | register, D-09 |
| 3.0 Run checks | Information Disclosure | In `alunduil-infrastructure`, updated code reads CI plan's credentials | High | Plan waits until the admin approves the update's head commit | Mitigated | `.github/workflows/terraform-plan.yml`, step `Hold a Renovate update until the admin approves it` |
| 3.0 Run checks | Denial of Service | A check never reports, which blocks the merge. The admin can bypass it only if `admin_bypassable_contexts` lists it | — | — | Not Applicable | `terraform/modules/github_repository/variables.tf`, `required_status_checks` |
| 3.0 Run checks | Elevation of Privilege | In `alunduil-infrastructure`, updated code acts with CI plan's credentials before anyone reviews it | High | Plan waits until the admin approves the update's head commit | Mitigated | `.github/workflows/terraform-plan.yml`, step `Hold a Renovate update until the admin approves it` |
| 4.0 Run hooks | Spoofing | A fork's pull request feeds the push | High | The job runs only when the head repository is the base | Mitigated | workflow, job `hooks`, `if` |
| 4.0 Run hooks | Tampering | Hook code writes any in-place edit into the diff, which the push job commits | High | #1057, `renovate-config#39` | Not Started | workflow, step `Capture fixes` |
| 4.0 Run hooks | Repudiation | Nothing ties a fix to the hook that made it once the run log expires | Low | #1057 has the operator review each fix | Not Started | workflow, step `Run hooks` |
| 4.0 Run hooks | Information Disclosure | Hook code reads a credential | Medium | The job holds no secret or `id-token`, and its read-only token isn't persisted | Mitigated | workflow, job `hooks`, `persist-credentials: false` |
| 4.0 Run hooks | Denial of Service | A hook loops or hangs | Low | A 15-minute timeout, and the hook-fix App's own pushes skip the job | Mitigated | workflow, job `hooks` |
| 4.0 Run hooks | Elevation of Privilege | Hook code writes a cache that a more trusted run restores | Medium | A pull request run's cache is scoped to its merge ref, so only that pull request restores it | Mitigated | GitHub's [dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching), and workflow, step `Install Node`, `cache: pnpm` |
| 5.0 Push hook fixes | Spoofing | A run Renovate didn't start pushes as C-25 | High | The provider admits only pull request runs by Renovate, or by the self-test App in `renovate-config` | Mitigated | `hook_fix.tf`, `extra_conditions` |
| 5.0 Push hook fixes | Tampering | The diff adds, deletes, or re-types a file, moves a submodule, or edits a workflow | High | The job refuses each of these | Mitigated | workflow, steps `Reject fixes that aren't in-place edits` and `Reject fixes to workflow files` |
| 5.0 Push hook fixes | Tampering | The diff edits a composite action, which a workflow then runs | High | `renovate-config#39` | Not Started | workflow, step `Reject fixes to workflow files` checks only `.github/workflows` |
| 5.0 Push hook fixes | Repudiation | Hook-fix commits are pushed with git, so GitHub doesn't sign them, and Renovate compares only the author email | Medium | #1057 | Not Started | behaviour, Modified-branch detection |
| 5.0 Push hook fixes | Information Disclosure | Code from the checkout reads the key | High | The job runs pinned actions and `git`, and nothing from the checkout | Mitigated | workflow, job `push` |
| 5.0 Push hook fixes | Denial of Service | A branch moves while the push job runs | — | — | Not Applicable | workflow, step `Push fixes` skips a moved branch, and the newer run fixes it |
| 5.0 Push hook fixes | Elevation of Privilege | Whoever lands a pin on a calling repository's default branch chooses what the job does with C-25 | High | `admin-only` on `renovate-config`, and #1282 | Not Started | `hook_fix.tf`, comment on `module.hook_fix_reader` |
| 6.0 Admit workflow | Spoofing | A token from a fork-only commit, or from a `renovate-config` branch, passes the prefix match | High | Renovate's runs call the default branch's pin, but the self-test App's call their branch's copy, #1289 | Not Started | `hook_fix.tf`, `extra_conditions` |
| 6.0 Admit workflow | Tampering | Changing the condition needs the bootstrap layer, which only the operator applies | — | — | Not Applicable | `docs/how-to/bootstrap.md` |
| 6.0 Admit workflow | Repudiation | Every admitted run acts as `hook-fix-reader`, so an unexpected read raises the same `Unexpected Data Access` warning as an expected one | Medium | The provider admits only pull request runs by Renovate, or by the self-test App in `renovate-config`, so every read is an expected one | Mitigated | `hook_fix.tf`, `extra_conditions` |
| 6.0 Admit workflow | Information Disclosure | The condition admits any alunduil repository, event, and actor | High | The provider admits only pull request runs by Renovate, or by the self-test App in `renovate-config` | Mitigated | `hook_fix.tf`, `extra_conditions` |
| 6.0 Admit workflow | Denial of Service | A Google Cloud outage stops fixes, and the pull request waits | — | — | Not Applicable | workflow, job `push` |
| 6.0 Admit workflow | Elevation of Privilege | The reader gains more than the App's two secrets | Medium | The reader holds no project role, only accessor on those secrets | Mitigated | `secret_reader.tf`, `google_secret_manager_secret_iam_member.reader` |
| 7.0 Merge pull request | Spoofing | GitHub accepts a merge from whoever holds a bypass, which the 1.0 and Operator rows cover | — | — | Not Applicable | `main.tf`, `local.merge_bypass_actors` |
| 7.0 Merge pull request | Tampering | A hook-fix commit lands on a default branch unreviewed | High | #1057 | Not Started | `main.tf`, `github_repository_ruleset.renovate` |
| 7.0 Merge pull request | Tampering | A compromised update automerges once its checks pass | High | `minimumReleaseAge`, release-job holds, and `renovate-config#82` | Not Started | `default.json`, `packageRules` |
| 7.0 Merge pull request | Repudiation | GitHub records the merger and the merged head on the pull request | — | — | Not Applicable | register, D-09 |
| 7.0 Merge pull request | Information Disclosure | Every repository here is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| 7.0 Merge pull request | Denial of Service | A failing check holds the update for the operator, which is the rule working | — | — | Not Applicable | `main.tf`, `github_repository_ruleset.checks` |
| 7.0 Merge pull request | Elevation of Privilege | A write collaborator merges a Renovate pull request past review | Medium | `admin-only` on every repository with write collaborators, except `zfs-replicate`, which requires Code Owner review | Mitigated | `repositories.tf`, `admin_only_updates` and `require_code_owner_review` |
| 8.0 Update shared config | Spoofing | A stolen collaborator account or a prompted Claude App session pushes to `renovate-config` | High | `admin-only` lets only the admin update the default branch | Mitigated | `repositories.tf`, `renovate-config` `admin_only_updates` |
| 8.0 Update shared config | Tampering | Anyone able to merge here changes every repository's automerge policy and hook-fix workflow | High | `admin-only` lets only the admin update the default branch | Mitigated | `repositories.tf`, `renovate-config` `admin_only_updates` |
| 8.0 Update shared config | Repudiation | A pushed commit's author is free text | Low | `admin-only` limits who updates the default branch | Mitigated | behaviour, Bot commit signing |
| 8.0 Update shared config | Information Disclosure | The preset and workflow are public by design | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| 8.0 Update shared config | Denial of Service | A broken preset stops Renovate in every repository until someone fixes it | Low | — | Not Applicable | `renovate-config`'s `.pre-commit-config.yaml` validates the preset, except presets named in `extends` |
| 8.0 Update shared config | Elevation of Privilege | A write actor's branch copy of the hook-fix workflow reads C-25 | High | The provider admits only pull request runs by Renovate, or by the self-test App in `renovate-config` | Mitigated | `hook_fix.tf`, `extra_conditions` |
| Shared config commits | Tampering | Renovate and every caller read the default branch with no review between them | High | `admin-only` lets only the admin update the default branch | Mitigated | `repositories.tf`, `renovate-config` `admin_only_updates` |
| Shared config commits | Repudiation | GitHub records each push and merge to the default branch | — | — | Not Applicable | register, D-09 |
| Shared config commits | Information Disclosure | The preset and workflow are public by design | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| Shared config commits | Denial of Service | Someone deletes or rewrites the default branch, which every caller's preset reads | Medium | `default` blocks deletion and force pushes | Mitigated | `main.tf`, `github_repository_ruleset.default` |
| Renovate branches | Tampering | A commit reaches the branch without passing 2.0 | — | — | Not Applicable | `main.tf`, `github_repository_ruleset.renovate` applies to every push |
| Renovate branches | Repudiation | Renovate counts a commit as its own when the author email matches `gitIgnoredAuthors` | Medium | #1057 | Not Started | behaviour, Modified-branch detection |
| Renovate branches | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| Renovate branches | Denial of Service | A deleted branch drops its update | Medium | #1269 | Not Started | `main.tf`, `github_repository_ruleset.renovate` sets only `update` |
| Default branch | Tampering | Someone rewrites the default branch | High | `default` blocks force pushes | Mitigated | `main.tf`, `github_repository_ruleset.default` |
| Default branch | Repudiation | GitHub records each merge on its pull request | — | — | Not Applicable | register, D-09 |
| Default branch | Information Disclosure | The default branch is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| Default branch | Denial of Service | Someone deletes the default branch | Medium | `default` blocks deletion | Mitigated | `main.tf`, `github_repository_ruleset.default` |
| Fix artifact | Tampering | Hook code writes the diff, so the artifact is as untrusted as the hooks | High | The push job's checks, and #1057 | Not Started | workflow, step `Capture fixes` |
| Fix artifact | Repudiation | The artifact expires after a day | Low | The fix commit and the run log outlast it | Mitigated | workflow, step `Upload fixes`, `retention-days: 1` |
| Fix artifact | Information Disclosure | The diff holds only source from a public repository | — | — | Not Applicable | workflow, step `Capture fixes` |
| Fix artifact | Denial of Service | A missing artifact fails the push, and the branch keeps Renovate's commit | — | — | Not Applicable | workflow, step `Download fixes` |
| Hook-fix secrets | Tampering | Adding a version needs project IAM, which reaches everything anyway | — | — | Not Applicable | `scripts/configure-hook-fix-secrets.sh` |
| Hook-fix secrets | Repudiation | Every read is logged as `hook-fix-reader`, whichever run made it | Medium | The provider admits only pull request runs by Renovate, or by the self-test App in `renovate-config`, so every read is an expected one | Mitigated | `hook_fix.tf`, `extra_conditions` |
| Hook-fix secrets | Information Disclosure | Any admitted run reads the key | High | The provider admits only pull request runs by Renovate, or by the self-test App in `renovate-config` | Mitigated | `hook_fix.tf`, `extra_conditions` |
| Hook-fix secrets | Denial of Service | A deleted or disabled version stops fixes, and pull requests wait | — | — | Not Applicable | workflow, step `Read App credentials` |
| F1 dependency release | Tampering | A re-pointed tag arrives as a digest update, which skips the release-age wait and automerges | High | `renovate-config#82` | Not Started | `default.json`, `packageRules`, and behaviour, Re-pointed tags behind digest pins |
| F1 dependency release | Information Disclosure | Releases are public | — | — | Not Applicable | register, P-6 |
| F1 dependency release | Denial of Service | A registry outage delays an update and loses nothing | — | — | Not Applicable | register, P-6 |
| F2 shared preset | Tampering | Renovate reads the preset from the default branch on each run, unpinned | High | `admin-only` lets only the admin update the default branch | Mitigated | `repositories.tf`, `renovate-config` `admin_only_updates` |
| F2 shared preset | Information Disclosure | The preset is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F2 shared preset | Denial of Service | A GitHub outage delays updates and loses nothing | — | — | Not Applicable | register, D-09 |
| F3 update commits | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub or Mend | — | — | Not Applicable | register, D-09 |
| F3 update commits | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F3 update commits | Denial of Service | A Mend outage delays updates and loses nothing | — | — | Not Applicable | register, P-6 |
| F4 created branch | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F4 created branch | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F4 created branch | Denial of Service | A flood of branches uses runner minutes on a public repository and merges nothing | — | — | Not Applicable | workflow, job `hooks` |
| F5 branch update | Tampering | Stays inside GitHub, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F5 branch update | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F5 branch update | Denial of Service | A GitHub outage delays the update and loses nothing | — | — | Not Applicable | register, D-09 |
| F6 branch code | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F6 branch code | Information Disclosure | The branch is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F6 branch code | Denial of Service | A GitHub outage delays the merge and loses nothing | — | — | Not Applicable | register, D-09 |
| F7 check results | Tampering | An App reports a result under a required check's name | Medium | #429 | Not Started | `main.tf`, `github_repository_ruleset.checks` |
| F7 check results | Information Disclosure | Check results are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F7 check results | Denial of Service | Codecov leaves a check in progress, which holds the merge | — | — | Not Applicable | `terraform/modules/github_repository/variables.tf`, `codecov_project_check` |
| F8 hook input | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F8 hook input | Information Disclosure | The branch is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F8 hook input | Denial of Service | A GitHub outage delays the fix and loses nothing | — | — | Not Applicable | register, D-09 |
| F9 hooks workflow | Tampering | A new `renovate-config` commit reaches callers as an automerging digest update | Medium | `admin-only` on `renovate-config`, and `renovate-config#21` | Not Started | `.github/workflows/ci.yml`, `uses` and `# main` in each calling repository |
| F9 hooks workflow | Information Disclosure | The workflow is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F9 hooks workflow | Denial of Service | A broken workflow stops fixes, and Renovate's commit still runs its checks | — | — | Not Applicable | `alunduil-infrastructure`'s `.github/workflows/ci.yml`, job `fix-renovate-hooks` isn't required |
| F10 push workflow | Tampering | The caller chooses the commit, so a branch or fork commit's copy gets the key | High | Renovate's runs call the default branch's pin, but the self-test App's call their branch's copy, #1289 | Not Started | `hook_fix.tf`, `extra_conditions` |
| F10 push workflow | Information Disclosure | The workflow is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F10 push workflow | Denial of Service | A broken workflow stops fixes, and Renovate's commit still runs its checks | — | — | Not Applicable | `alunduil-infrastructure`'s `.github/workflows/ci.yml`, job `fix-renovate-hooks` isn't required |
| F11 fix diff | Tampering | Hook code chooses the diff | High | The push job's checks, and #1057 | Not Started | workflow, step `Capture fixes` |
| F11 fix diff | Information Disclosure | The diff holds only public source | — | — | Not Applicable | workflow, step `Capture fixes` |
| F11 fix diff | Denial of Service | A failed upload stops the push, and the branch keeps Renovate's commit | — | — | Not Applicable | workflow, step `Upload fixes`, `if-no-files-found: error` |
| F12 stored diff | Tampering | Stays inside GitHub, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F12 stored diff | Information Disclosure | The diff holds only public source | — | — | Not Applicable | workflow, step `Download fixes` |
| F12 stored diff | Denial of Service | A failed download stops the push, and the branch keeps Renovate's commit | — | — | Not Applicable | workflow, step `Download fixes` |
| F13 OIDC token | Tampering | GitHub signs the token, so changing it invalidates it | — | — | Not Applicable | `secret_reader.tf`, `oidc.issuer_uri` |
| F13 OIDC token | Information Disclosure | The token is worth only what the provider's condition admits, which 6.0 covers | — | — | Not Applicable | `hook_fix.tf`, `extra_conditions` |
| F13 OIDC token | Denial of Service | A GitHub outage stops fixes and loses nothing | — | — | Not Applicable | register, D-09 |
| F14 reader token | Tampering | Google Cloud carries this over TLS, so tampering needs a compromise of Google | — | — | Not Applicable | workflow, step `Authenticate to Google Cloud` |
| F14 reader token | Information Disclosure | The token reaches only the job's steps | Low | The job runs pinned actions and `git`, and nothing from the checkout | Mitigated | workflow, job `push` |
| F14 reader token | Denial of Service | A Google Cloud outage stops fixes and loses nothing | — | — | Not Applicable | workflow, job `push` |
| F15 App ID and key | Tampering | Google Cloud carries this over TLS, so tampering needs a compromise of Google | — | — | Not Applicable | workflow, step `Read App credentials` |
| F15 App ID and key | Information Disclosure | The key sits in step outputs while later steps run | Medium | The later steps run pinned actions and `git`, and nothing from the checkout | Mitigated | workflow, job `push` |
| F15 App ID and key | Denial of Service | A failed read stops fixes and loses nothing | — | — | Not Applicable | workflow, step `Read App credentials` |
| F16 fix commit | Tampering | The commit carries hook output nobody reviewed | High | #1057 | Not Started | workflow, step `Push fixes` |
| F16 fix commit | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F16 fix commit | Denial of Service | A rejected push leaves the branch as Renovate wrote it | — | — | Not Applicable | workflow, step `Push fixes` |
| F17 merge request | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub or Mend | — | — | Not Applicable | register, D-09 |
| F17 merge request | Information Disclosure | Merges are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F17 merge request | Denial of Service | A Mend outage delays the merge and loses nothing | — | — | Not Applicable | register, P-6 |
| F18 review decision | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F18 review decision | Information Disclosure | Reviews are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F18 review decision | Denial of Service | A held update waits for the operator, which is the hold working | — | — | Not Applicable | `default.json`, `reviewers` |
| F19 merged commit | Tampering | Stays inside GitHub, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F19 merged commit | Information Disclosure | The default branch is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F19 merged commit | Denial of Service | A GitHub outage delays the merge and loses nothing | — | — | Not Applicable | register, D-09 |
| F20 shared config change | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F20 shared config change | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F20 shared config change | Denial of Service | A GitHub outage delays the change and loses nothing | — | — | Not Applicable | register, D-09 |
| F21 operator preset change | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F21 operator preset change | Information Disclosure | The preset is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F21 operator preset change | Denial of Service | A GitHub outage delays the change and loses nothing | — | — | Not Applicable | register, D-09 |
| F22 shared config commit | Tampering | Stays inside GitHub, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F22 shared config commit | Information Disclosure | The preset and workflow are public by design | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F22 shared config commit | Denial of Service | A GitHub outage delays the change and loses nothing | — | — | Not Applicable | register, D-09 |
| F23 review request | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub or Mend | — | — | Not Applicable | register, D-09 |
| F23 review request | Information Disclosure | Review requests are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F23 review request | Denial of Service | A missed request leaves a held update open, which the operator's review queue still lists | — | — | Not Applicable | `default.json`, `reviewers` |
