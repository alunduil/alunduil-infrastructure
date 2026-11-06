<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->
<!-- markdownlint-disable MD013 -- a threat table's rows can't wrap -->

# Release path threat model

What can go wrong between a commit and a published package, and where the
release App #556 plans should sit given that. Registry uploads can't be
recalled, so this model weighs who can start one above everything else.

Verified 2026-11-06.

## Scope

Written for the operator deciding how a new release credential fits. It walks
every element of the [release path data
flow](release-path-data-flow.md) using STRIDE, and assumes the [asset
register](../reference/asset-register.md) and [credential
reachability](credential-reachability.md).

The rows come from reading configuration, workflows, and GitHub's documentation.
Nobody has tried these attacks, and #1065 tests what the planned controls
assume.

Out of scope:

- P-1's own compromise beyond the tokens that act as it. #1066 covers the
  workstation.
- Compromise of GitHub, Mend, or Anthropic. [Credential reachability](
  credential-reachability.md#why-renovate-and-the-claude-app-are-accepted)
  explains why Mend and Anthropic are accepted.

## Where the release App fits

A per-repository App should create release tags, and a person should merge the
release pull request until #1075 decides otherwise. The findings below drive
that choice.

| Candidate | Who creates the tag | Result |
| --- | --- | --- |
| Operator by hand | P-1 | No new credential, but it misses the milestone's no-manual-step objective |
| `GITHUB_TOKEN` | P-11 | Its Release starts no workflow and its pull request runs no checks. A dispatch would start a run, but #1055's bypass list would then have to admit P-11, which GitHub's documentation doesn't list as an option |
| One App per repository | P-12 | Chosen. A leak reaches one repository, provided #1057 and #1076 close the routes between repositories |
| One App across repositories | P-12 | Rejected. One leaked key would tag and publish in all of them |
| Tag as a record, publish from `main` (`network-arbitrary#241`) | P-12 | Rejected. A leaked tag credential can't publish, but anyone able to dispatch can, and `hackage` can't then be scoped to tags |

That answers #556's open questions:

- **Permissions:** `Contents` and `Pull requests` write. `Contents` write also
  allows pushing unprotected branches and replacing Release assets, which is
  why each repository gets its own App.
- **Installation:** one repository per App. Each key sits in Secret Manager
  behind a reader that only that repository's default branch and `release`
  environment can use. This replaces the Actions secrets
  `collection-json.hs#307` and #749 name, which settles the naming divergence.
- **The job holding the key:** pinned actions only, with no checkout and no
  repository code.
- **Tag ruleset:** yes. #1055 restricts creation to the admin role and the App.
  The App stays off `immutable-tags`.
- **Environments:** `deployment_tags` stays, and #697 closes the last gap.
  It checks a name, so it only means something alongside #1055.
- **Tag creation in the shared Hackage workflow:** the App creates the
  prerelease after the merge, as `collection-json.hs#409` describes. The App
  needs no merge bypass unless a repository merges its own pull request, which
  is what #797 adds.

Three limits remain:

- The App still lets a leaked key create a tag on an off-branch commit. A
  workflow check refuses that only because the App lacks `Workflows`
  permission, so `zfs-replicate#827` and `network-arbitrary#172` have to carry
  the check.
- Per-repository Apps don't separate the Hackage packages, because each token
  acts as a Hackage user (#1093).
- Nothing alerts on an unexpected tag or upload until #1064 lands.

## Findings

Every unmitigated row below points to one of these.

| Finding | Issue |
| --- | --- |
| Anyone with `Contents` write can create a tag that publishes | #1055 |
| A release workflow accepts a tag that isn't on the default branch | `zfs-replicate#827`, `network-arbitrary#172` |
| Tokens acting as the account bypass the tag rule | #1076, #1069, #738 |
| Hook-fix commits reach a default branch unreviewed | #1057 |
| A dependency update can merge and ship with nobody looking | #1075 |
| A required check can be satisfied by any App reporting its name | #429 |
| A write collaborator can dispatch a publish on an existing tag | `collection-json.hs#406`, #1077 |
| Build code shares a job with the Hackage token | `collection-json.hs#454`, `network-arbitrary#172` |
| Build code shares a job with `Contents` write | `woodland-generators#922` |
| A build can restore a poisoned cache | #1079 |
| A Hackage token uploads every package its account can | #1093 |
| Release assets can be replaced | `woodland-generators#915` |
| A failed smoke test leaves a tag only the admin can remove | `collection-json.hs#161` |
| Nobody is told about an unexpected tag or upload | #1064 |
| A published package can't be verified against its build | #1078 |
| `siren-json.hs`'s `hackage` environment admits any ref | #697 |
| A required check never reports on a `GITHUB_TOKEN` pull request | #556 |

## Threats

Priority ranks what the operator would stop to fix. In the Evidence column,
`main.tf` is `terraform/modules/github_repository/main.tf`, `register` is
`docs/reference/asset-register.md`, and `release.yml` is
`.github/workflows/release.yml` in the named repository.

### Context

| Element | Category | Threat | Priority | Mitigation | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 0 Release a package | All | Analysed through its decomposition at Level 0 | — | — | Not Applicable | `release-path-data-flow.md`, Level 0 |

### Level 0

| Element | Category | Threat | Priority | Mitigation | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Contributor | Spoofing | A stolen account opens a pull request as its owner, which still has to pass review | Low | Rulesets gate the merge | Mitigated | `main.tf`, `github_repository_ruleset.review` |
| Contributor | Repudiation | A contributor denies a pull request, but it changes nothing until someone merges it | — | — | Not Applicable | `main.tf`, `github_repository_ruleset.review` |
| Write actor | Spoofing | A leaked C-25 key acts as P-5 in any repository the App is installed on | High | #1057, #1055 | Not Started | register, C-25 |
| Write actor | Spoofing | A stolen collaborator account creates a tag as that person | High | #1055 | Not Started | `main.tf`, `github_repository_ruleset.immutable_tags` has no creation rule |
| Write actor | Repudiation | A lightweight tag records no creator, so its creator can deny it | Medium | #1064 | Not Started | — |
| Operator | Spoofing | A stolen C-13 or C-32 acts as the account and bypasses every ruleset | High | #1076, #1069, #738 | Not Started | register, C-13 and C-32 |
| Operator | Repudiation | Actions by C-13 and C-32 look like the operator's own | Medium | #1076, #1064 | Not Started | `woodland-generators` releases report the account as author |
| Hackage | Spoofing | Something impersonates Hackage to `cabal upload` | Low | cabal upgrades Hackage's URL to HTTPS, and exits if its transport lacks HTTPS | Mitigated | `haskell/cabal`, `Distribution.Client.Upload.upload` calls `remoteRepoTryUpgradeToHttps` |
| Hackage | Repudiation | Hackage's record is the only one of what it accepted | Low | #1064 compares registry versions with tags | Not Started | — |
| PyPI | Spoofing | Something impersonates PyPI to the publish action | Low | TLS, by the pinned action | Mitigated | `zfs-replicate` `release.yml`, job `pypi` |
| PyPI | Repudiation | PyPI's record is the only one of what it accepted | Low | #1064 compares registry versions with tags | Not Started | — |
| Foundry world | Spoofing | A world authenticates to nothing and holds nothing here | — | — | Not Applicable | `woodland-generators` `release.yml`, job `verify-release` |
| Foundry world | Repudiation | A world takes no action the path depends on | — | — | Not Applicable | `woodland-generators` `release.yml`, job `verify-release` |
| 1.0 Merge pull request | Spoofing | An App reporting a required check's name satisfies it | Medium | #429 | Not Started | `main.tf`, `github_repository_ruleset.checks` |
| 1.0 Merge pull request | Tampering | A hook-fix commit lands on a default branch unreviewed | High | #1057 | Not Started | `main.tf`, `github_repository_ruleset.renovate` |
| 1.0 Merge pull request | Tampering | A compromised dependency update automerges and ships in the next release | High | #1075 | Not Started | `terraform/alunduil/repositories.tf`, `renovate_automerge` |
| 1.0 Merge pull request | Repudiation | GitHub records the merger and the merged head on the pull request | — | — | Not Applicable | register, D-09 |
| 1.0 Merge pull request | Information Disclosure | Every repository here is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| 1.0 Merge pull request | Denial of Service | A pull request opened by P-11 runs no workflows, so required checks never report | Medium | #556 | Not Started | `main.tf`, `github_workflow_repository_permissions` |
| 1.0 Merge pull request | Elevation of Privilege | A write collaborator merges past review | Medium | `admin-only` and `review`. On `zfs-replicate`, Code Owner review | Mitigated | `main.tf`, `github_repository_ruleset.admin_only` |
| 3.0 Create tag or Release | Spoofing | GitHub treats whoever presents a valid credential as its owner, which the Write actor and Operator rows cover | — | — | Not Applicable | register, D-09 |
| 3.0 Create tag or Release | Tampering | A `Contents` write actor creates a matching tag on any commit, which picks the source that publishes | High | #1055, `zfs-replicate#827`, `network-arbitrary#172` | Not Started | `main.tf`, `github_repository_ruleset.immutable_tags` |
| 3.0 Create tag or Release | Tampering | Someone moves or deletes a published tag | High | `immutable-tags` | Mitigated | `main.tf`, `github_repository_ruleset.immutable_tags` |
| 3.0 Create tag or Release | Repudiation | No record names who created a tag | Medium | #1064 | Not Started | — |
| 3.0 Create tag or Release | Information Disclosure | Tags and published Releases are public by design | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| 3.0 Create tag or Release | Denial of Service | A failed smoke test leaves a tag only the admin can delete, which may burn the version | Medium | `collection-json.hs#161` | Not Started | `main.tf`, `github_repository_ruleset.immutable_tags` |
| 3.0 Create tag or Release | Denial of Service | A write actor creates a future version's tag on a junk commit, and immutability keeps it there | Low | #1055 | Not Started | `main.tf`, `github_repository_ruleset.immutable_tags` |
| 3.0 Create tag or Release | Elevation of Privilege | Tag creation gives a write actor the publish that review denies them | High | #1055 | Not Started | `main.tf`, `github_repository_ruleset.immutable_tags` |
| Repository commits | Tampering | An unreviewed commit on a side branch becomes a release through a tag | High | #1055, `zfs-replicate#827` | Not Started | `zfs-replicate` `release.yml`, job `build` |
| Repository commits | Tampering | Someone rewrites or deletes the default branch | High | `default` blocks force pushes and deletion | Mitigated | `main.tf`, `github_repository_ruleset.default` |
| Repository commits | Repudiation | A key holder can set any commit author, and Renovate compares only the email | Medium | #1057 | Not Started | — |
| Repository commits | Information Disclosure | A secret is committed to a public repository | Medium | Push protection and secret scanning | Mitigated | `main.tf`, `github_repository.this` `security_and_analysis` |
| Repository commits | Denial of Service | Someone deletes the default branch | High | `default` blocks deletion | Mitigated | `main.tf`, `github_repository_ruleset.default` |
| Tags and Releases | Tampering | A `Contents` write actor replaces a published module's assets | High | `woodland-generators#915` | Not Started | `gh api repos/alunduil/woodland-generators/immutable-releases` reports disabled |
| Tags and Releases | Tampering | A write actor edits a Release's prerelease flag or notes, which `metadata` reads live | Low | #1078 | Not Started | `collection-json.hs` `release.yml`, job `metadata` |
| Tags and Releases | Repudiation | A Release edit leaves nobody a record the operator can read | Medium | #1064 | Not Started | — |
| Tags and Releases | Information Disclosure | Tags and published Releases are public by design | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| Tags and Releases | Denial of Service | A write actor deletes a Release, which breaks Foundry's latest-release manifest URL | Medium | #1064 | Not Started | `woodland-generators` `release.yml`, job `verify-release` |
| Repository secrets | Tampering | Changing a secret needs the admin role, which reaches everything anyway | — | — | Not Applicable | register, P-1 |
| Repository secrets | Repudiation | Nothing records which run read C-32 | Medium | #738 removes it | Not Started | `woodland-generators` `release.yml`, job `release-please` |
| Repository secrets | Information Disclosure | Any workflow on any branch can read C-32, because no environment holds it | High | #738 | Not Started | `woodland-generators` `release.yml`, job `release-please` |
| Repository secrets | Denial of Service | C-32 has no expiry, and only the admin can delete it | — | — | Not Applicable | register, C-32 |
| Environment secrets | Tampering | Changing a secret needs the admin role, which reaches everything anyway | — | — | Not Applicable | register, P-1 |
| Environment secrets | Repudiation | A run denies reading a token | Low | GitHub records each deployment to an environment | Mitigated | `main.tf`, `github_repository_environment.this` |
| Environment secrets | Information Disclosure | Any `v*` tag on any commit admits its job to the environment, because the rule checks the name | High | #1055 | Not Started | `main.tf`, `github_repository_environment_deployment_policy` |
| Environment secrets | Information Disclosure | `siren-json.hs`'s `hackage` environment admits any ref. It holds no secret yet | Low | #697 | Not Started | `terraform/alunduil/repositories.tf`, `siren-json.hs` |
| Environment secrets | Denial of Service | Deleting a token needs the admin role, and only delays a release | — | — | Not Applicable | register, P-1 |
| 2.0 Prepare release | Spoofing | Only a push to `main` starts this job, so review already gated its input | — | — | Not Applicable | `woodland-generators` `release.yml`, `on.push` |
| 2.0 Prepare release | Tampering | A changed release-please action alters what the job does with C-32 | Medium | SHA pinning, and #738 removes the token | Not Started | `main.tf`, `sha_pinning_required` |
| 2.0 Prepare release | Repudiation | Its commits and tags are attributed to the account rather than a bot | Low | #738 | Not Started | `woodland-generators` `release.yml`, `secrets.PAT_TOKEN` |
| 2.0 Prepare release | Information Disclosure | C-32 appears in the job's logs | Low | Actions masks secrets | Mitigated | `woodland-generators` `release.yml`, `secrets.PAT_TOKEN` |
| 2.0 Prepare release | Denial of Service | A failed run delays a release and loses nothing, since the next push repeats it | — | — | Not Applicable | `woodland-generators` `release.yml`, `on.push` |
| 2.0 Prepare release | Elevation of Privilege | A third-party action holds a token with the account's ruleset bypasses | High | #738, #1076 | Not Started | register, C-32 |
| 4.0 Build package | Spoofing | A write collaborator's dispatch runs the workflow on an existing tag | Medium | `collection-json.hs#406`, #1077 | Not Started | `collection-json.hs` `release.yml`, `on.workflow_dispatch` |
| 4.0 Build package | Tampering | A restored cache carries code a lower-trust run wrote | Medium | #1079 | Not Started | `zfs-replicate` `.github/actions/setup-poetry`, `cache: poetry` |
| 4.0 Build package | Tampering | A moved action tag changes what the build runs | Medium | SHA pinning and an action allow-list | Mitigated | `main.tf`, `sha_pinning_required` |
| 4.0 Build package | Repudiation | Run logs expire after 90 days, while a registry upload stays | Low | #1078 | Not Started | `gh api repos/alunduil/zfs-replicate/actions/permissions/artifact-and-log-retention` |
| 4.0 Build package | Information Disclosure | A build job holding no secret has nothing to leak | — | — | Not Applicable | `zfs-replicate` `release.yml`, job `build` |
| 4.0 Build package | Denial of Service | A failed build publishes nothing, and a re-run keeps the tag | — | — | Not Applicable | `zfs-replicate` `release.yml`, job `build` |
| 4.0 Build package | Elevation of Privilege | Build code reaches the Hackage token through a later step in its job | High | `collection-json.hs#454` | Not Started | `collection-json.hs` `release.yml`, job `candidate` |
| 4.0 Build package | Elevation of Privilege | Build code reaches `Contents` write through a later step in its job | High | `woodland-generators#922` | Not Started | `woodland-generators` `release.yml`, job `publish-module` |
| 6.0 Attach Release assets | Spoofing | A write actor uploads an asset the workflow appears to have built | High | `woodland-generators#915` | Not Started | `woodland-generators` `release.yml`, job `publish-module` |
| 6.0 Attach Release assets | Tampering | `--clobber` replaces an asset already attached | High | `woodland-generators#915` | Not Started | `woodland-generators` `release.yml`, job `publish-module` |
| 6.0 Attach Release assets | Repudiation | Nothing ties an asset to the run that built it | Medium | #1078 | Not Started | — |
| 6.0 Attach Release assets | Information Disclosure | Release assets are public by design | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| 6.0 Attach Release assets | Denial of Service | A bad asset stops Foundry installing the module | Medium | `verify-release` installs from the manifest URL | Mitigated | `woodland-generators` `release.yml`, job `verify-release` |
| 6.0 Attach Release assets | Elevation of Privilege | Build code in this job can create tags, because the job holds `Contents` write | High | `woodland-generators#922` | Not Started | `woodland-generators` `release.yml`, job `publish-module` |
| Build artifacts | Tampering | The artifact differs from what Hackage smoke-tested | High | `publish` compares it with the candidate | Mitigated | `collection-json.hs` `release.yml`, job `publish` |
| Build artifacts | Repudiation | Nothing proves which run produced an artifact once it expires | Low | #1078 | Not Started | — |
| Build artifacts | Information Disclosure | An artifact holds only the package, which is public | — | — | Not Applicable | `zfs-replicate` `release.yml`, job `build` |
| Build artifacts | Denial of Service | An expired artifact fails `Find candidate run`, and a new version recovers | — | — | Not Applicable | `collection-json.hs` `release.yml`, job `publish` |
| 5.0 Upload package | Spoofing | Any run on a `v*` ref passes as a release | High | #1055 | Not Started | `main.tf`, `github_repository_environment_deployment_policy` |
| 5.0 Upload package | Tampering | The package holds source from an off-branch tag | High | `zfs-replicate#827`, `network-arbitrary#172` | Not Started | `network-arbitrary` `release.yml`, job `publish` |
| 5.0 Upload package | Repudiation | A Hackage upload names the account, not the run | Medium | #1078 | Not Started | — |
| 5.0 Upload package | Information Disclosure | `network-arbitrary` passes its key on the command line | Low | `network-arbitrary#172` | Not Started | `network-arbitrary` `release.yml`, step `cabal upload` |
| 5.0 Upload package | Denial of Service | A registry outage fails the job, and a re-run keeps the tag | — | — | Not Applicable | `collection-json.hs` `release.yml`, job `publish` |
| 5.0 Upload package | Elevation of Privilege | A write collaborator's dispatch publishes a candidate the operator hasn't released | High | `collection-json.hs#406`, #1077 | Not Started | `collection-json.hs` `release.yml`, job `publish` |
| F1 proposed commits | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F1 proposed commits | Information Disclosure | Pull requests are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F1 proposed commits | Denial of Service | A flood of pull requests delays review and publishes nothing | — | — | Not Applicable | `main.tf`, `github_repository_ruleset.review` |
| F2 pushed commits | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F2 pushed commits | Information Disclosure | Branches are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F2 pushed commits | Denial of Service | A GitHub outage delays a release and loses nothing | — | — | Not Applicable | register, D-09 |
| F3 review decision | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F3 review decision | Information Disclosure | Reviews are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F3 review decision | Denial of Service | A missing review delays a release and loses nothing | — | — | Not Applicable | `main.tf`, `github_repository_ruleset.review` |
| F4 merged commit | Tampering | Stays inside GitHub, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F4 merged commit | Information Disclosure | The default branch is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F4 merged commit | Denial of Service | A GitHub outage delays a release and loses nothing | — | — | Not Applicable | register, D-09 |
| F5 merged history | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F5 merged history | Information Disclosure | The default branch is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F5 merged history | Denial of Service | A GitHub outage delays a release and loses nothing | — | — | Not Applicable | register, D-09 |
| F6 account token | Tampering | Stays inside GitHub, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F6 account token | Information Disclosure | C-32 reaches the third-party release-please action | High | #738 | Not Started | `woodland-generators` `release.yml`, job `release-please` |
| F6 account token | Denial of Service | A missing secret fails the job and publishes nothing | — | — | Not Applicable | `woodland-generators` `release.yml`, job `release-please` |
| F7 release pull request | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F7 release pull request | Information Disclosure | Pull requests are public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F7 release pull request | Denial of Service | A GitHub outage delays a release and loses nothing | — | — | Not Applicable | register, D-09 |
| F8 prepared tag request | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F8 prepared tag request | Information Disclosure | The tag it requests is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F8 prepared tag request | Denial of Service | A GitHub outage delays a release and loses nothing | — | — | Not Applicable | register, D-09 |
| F9 tag request | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F9 tag request | Information Disclosure | The tag it requests is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F9 tag request | Denial of Service | A GitHub outage delays a release and loses nothing | — | — | Not Applicable | register, D-09 |
| F10 operator tag request | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F10 operator tag request | Information Disclosure | The tag it requests is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F10 operator tag request | Denial of Service | A GitHub outage delays a release and loses nothing | — | — | Not Applicable | register, D-09 |
| F11 tag and Release | Tampering | Stays inside GitHub, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F11 tag and Release | Information Disclosure | Tags and published Releases are public by design | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F11 tag and Release | Denial of Service | A Release P-11 creates starts no workflow, so nothing publishes | Low | No flow here creates its Release with P-11 | Mitigated | `woodland-generators` `release.yml`, `secrets.PAT_TOKEN` |
| F12 release ref | Tampering | A re-run reuses the event payload, so stale Release data could steer it | Low | `metadata` reads the Release live | Mitigated | `collection-json.hs` `release.yml`, job `metadata` |
| F12 release ref | Information Disclosure | The ref names a public tag | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F12 release ref | Denial of Service | A GitHub outage delays a release and loses nothing | — | — | Not Applicable | register, D-09 |
| F13 source and workflow | Tampering | The tag selects the workflow that runs, so a writer able to change workflows can remove its checks | High | #1055 | Not Started | `collection-json.hs` `release.yml`, step `Require the tag on main` |
| F13 source and workflow | Information Disclosure | The source is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F13 source and workflow | Denial of Service | A GitHub outage delays a release and loses nothing | — | — | Not Applicable | register, D-09 |
| F14 dispatched ref | Tampering | The dispatcher picks the ref, and the environment checks only its name | Medium | `collection-json.hs#406`, #1077 | Not Started | `collection-json.hs` `release.yml`, `on.workflow_dispatch` |
| F14 dispatched ref | Information Disclosure | The ref names a public tag | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F14 dispatched ref | Denial of Service | Repeated dispatches use runner minutes on a public repository and publish nothing new, since a version uploads once | — | — | Not Applicable | `collection-json.hs` `release.yml`, job `publish` |
| F15 operator dispatched ref | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F15 operator dispatched ref | Information Disclosure | The ref names a public tag | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F15 operator dispatched ref | Denial of Service | A GitHub outage delays a release and loses nothing | — | — | Not Applicable | register, D-09 |
| F16 package | Tampering | An earlier step in the build changes the package before upload | Medium | #1079 | Not Started | `zfs-replicate` `release.yml`, job `build` |
| F16 package | Information Disclosure | The package is public once published | — | — | Not Applicable | `zfs-replicate` `release.yml`, job `build` |
| F16 package | Denial of Service | `if-no-files-found: error` fails an empty upload, which publishes nothing | — | — | Not Applicable | `collection-json.hs` `release.yml`, job `candidate` |
| F17 built package | Tampering | The package changes between its upload and download | Medium | The `publish` comparison on `collection-json.hs`, and one run on `zfs-replicate` | Mitigated | `collection-json.hs` `release.yml`, job `publish` |
| F17 built package | Information Disclosure | The package is public once published | — | — | Not Applicable | `zfs-replicate` `release.yml`, job `pypi` |
| F17 built package | Denial of Service | A missing artifact fails the job, which publishes nothing | — | — | Not Applicable | `zfs-replicate` `release.yml`, job `pypi` |
| F18 Hackage token | Tampering | Stays inside GitHub, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F18 Hackage token | Information Disclosure | Earlier steps in the job can reach the token | High | `collection-json.hs#454` | Not Started | `collection-json.hs` `release.yml`, job `candidate` |
| F18 Hackage token | Denial of Service | A ref outside the pattern is refused, which is the rule working | — | — | Not Applicable | `main.tf`, `github_repository_environment_deployment_policy` |
| F19 Hackage upload | Tampering | The upload changes in transit | Low | cabal upgrades Hackage's URL to HTTPS, and exits if its transport lacks HTTPS | Mitigated | `haskell/cabal`, `Distribution.Client.Upload.upload` calls `remoteRepoTryUpgradeToHttps` |
| F19 Hackage upload | Information Disclosure | A token leaked from one repository uploads every package its account can | High | #1093 | Not Started | register, C-29 and C-30 |
| F19 Hackage upload | Denial of Service | A Hackage outage fails the job, and a re-run keeps the tag | — | — | Not Applicable | `collection-json.hs` `release.yml`, job `publish` |
| F20 candidate tarball | Tampering | The tarball Hackage returns differs from the built one | High | `publish` compares them before publishing | Mitigated | `collection-json.hs` `release.yml`, job `publish` |
| F20 candidate tarball | Information Disclosure | A candidate is public on Hackage | — | — | Not Applicable | `collection-json.hs` `release.yml`, job `metadata` |
| F20 candidate tarball | Denial of Service | A failed download stops the publish, which is the safe result | — | — | Not Applicable | `collection-json.hs` `release.yml`, job `publish` |
| F21 PyPI publish request | Tampering | The request changes in transit | Low | TLS, by the pinned action | Mitigated | `zfs-replicate` `release.yml`, job `pypi` |
| F21 PyPI publish request | Information Disclosure | The Trusted Publisher accepts more than this workflow. A Terraform comment states what PyPI pins, but PyPI's settings are unread | Medium | The operator reads the Trusted Publisher on PyPI | Needs Investigation | `terraform/alunduil/repositories.tf`, `zfs-replicate` `environments` |
| F21 PyPI publish request | Denial of Service | A renamed workflow or environment stops publishing, and nothing else | — | — | Not Applicable | `zfs-replicate` `release.yml`, job `pypi` |
| F22 PyPI upload token | Tampering | The token changes in transit | Low | TLS, by the pinned action | Mitigated | `zfs-replicate` `release.yml`, job `pypi` |
| F22 PyPI upload token | Information Disclosure | The job holding the token runs other code | Medium | The `pypi` job checks nothing out and runs only pinned actions | Mitigated | `zfs-replicate` `release.yml`, job `pypi` |
| F22 PyPI upload token | Denial of Service | A PyPI outage fails the job, and a re-run keeps the tag | — | — | Not Applicable | `zfs-replicate` `release.yml`, job `pypi` |
| F23 release state | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F23 release state | Information Disclosure | A Release's state is public | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F23 release state | Denial of Service | A failed promotion leaves a prerelease marking a stalled release | — | — | Not Applicable | `collection-json.hs` `release.yml`, job `promote-release` |
| F24 module assets | Tampering | Build code changes the assets, because it shares their job | High | `woodland-generators#922` | Not Started | `woodland-generators` `release.yml`, job `publish-module` |
| F24 module assets | Information Disclosure | The assets are public once attached | — | — | Not Applicable | `woodland-generators` `release.yml`, job `publish-module` |
| F24 module assets | Denial of Service | A failed build attaches nothing, and `verify-release` then fails | — | — | Not Applicable | `woodland-generators` `release.yml`, job `verify-release` |
| F25 replacement assets | Tampering | A write actor swaps a published module's zip | High | `woodland-generators#915` | Not Started | `woodland-generators` `release.yml`, job `publish-module` |
| F25 replacement assets | Information Disclosure | Release assets are public by design | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F25 replacement assets | Denial of Service | A write actor uploads a broken zip, and nothing re-checks after `verify-release` | Medium | `woodland-generators#915` | Not Started | `woodland-generators` `release.yml`, job `verify-release` |
| F26 stored assets | Tampering | GitHub carries this over TLS, so tampering needs a compromise of GitHub | — | — | Not Applicable | register, D-09 |
| F26 stored assets | Information Disclosure | Release assets are public by design | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F26 stored assets | Denial of Service | A GitHub outage delays a release and loses nothing | — | — | Not Applicable | register, D-09 |
| F27 manifest and zip | Tampering | Foundry has no way to verify the zip against its build | Medium | #1078, `woodland-generators#915` | Not Started | `woodland-generators` `release.yml`, job `verify-release` |
| F27 manifest and zip | Information Disclosure | Release assets are public by design | — | — | Not Applicable | `main.tf`, `github_repository.this` `visibility` |
| F27 manifest and zip | Denial of Service | A GitHub outage blocks a new install, and installed worlds keep working | — | — | Not Applicable | register, D-09 |
