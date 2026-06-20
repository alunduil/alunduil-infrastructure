<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# GitHub repository settings baseline

Every managed repository is created through the
`terraform/modules/github_repository` module, so the module's hard-coded
values _are_ the baseline: a repo that passes nothing but its name already
meets it. This document explains why the baseline is what it is, and — more
usefully — why a few settings the baseline _could_ enforce are deliberately
left out.

## Why a baseline at all

These repositories are personal and public, maintained by one person. The risk
they share is not a rogue collaborator; it is drift. Settings changed by hand in
the GitHub UI accumulate silently until an import or an apply quietly downgrades
one of them. Encoding the common settings once, in the module, makes the
strictness story legible in a single place and makes any per-repo exception an
explicit override in `repositories.tf` rather than an invisible click in a
settings page.

## Repository settings

The module fixes visibility to public, keeps issues on, and turns projects and
wikis off — these are libraries and tools, documented in their READMEs, not
wiki-driven. Discussions are off by default and opt-in per repo
(`woodland-generators` enables them) because discussions only earn their keep
where a user community actually asks questions.

Merging is squash-only: merge commits and rebase merges are disabled, the squash
commit takes the PR title and body, branches delete on merge, and destroyed
repos archive rather than vanish. A linear, one-commit-per-PR history is the
point — it pairs with the linear-history rule below and keeps the default branch
readable without a merge-bubble graph.

## Security

Secret scanning and its push protection are enabled. Both are free on public
repositories, and push protection is the cheap, high-value half: it blocks a
credential from reaching the remote at all rather than alerting after it has
already been pushed and must be rotated.

Vulnerability alerts are on (a separate resource in the module). Dependency
_updates_ are Renovate's job, not Dependabot's — see `renovate.json` — so the
baseline does not enable Dependabot version updates and would only duplicate
Renovate if it did.

## Default-branch protection

Protection is expressed as a `github_repository_ruleset`, not the classic
`github_branch_protection` resource. Two reasons. Rulesets are the mechanism
GitHub is actively investing in and steering its own docs toward. More
concretely, rulesets have first-class _bypass actors_, and a solo maintainer
needs one: any rule that requires a second human (an approving review) is
unsatisfiable alone, and any rule that blocks direct pushes would otherwise wall
off the maintainer from their own default branch.

The ruleset targets `~DEFAULT_BRANCH` and enforces:

- **Pull request required, zero approvals, conversation resolution required.**
  The default path to the default branch is a PR with its threads resolved. Zero
  approvals because there is no second reviewer to give one; see the exclusions
  below.
- **No force pushes** (`non_fast_forward`) and **no deletion**. The default
  branch cannot be rewritten or removed.
- **Linear history.** Matches the squash-only merge policy; the branch stays a
  straight line.

The repository **admin role bypasses with mode `always`**. This is what makes
the PR requirement livable: the baseline expresses the _intended_ path
(PR, resolved conversations) without locking the maintainer out of a direct push
when one is genuinely wanted. An out-of-band ruleset previously enforced the PR
rule with no bypass and had to be deleted by hand the first time a direct push to
`main` was rejected; encoding the bypass actor is the fix for that, not a
loophole around the policy.

## Deliberate exclusions

These are settings the baseline could enforce and intentionally does not. Each
is a judgement call, recorded so a future reader does not "fix" a gap that is
actually a decision.

- **No required approving reviews.** A required review count above zero cannot be
  met by one person without a bot or a second account approving its own work,
  which is approval theatre. The PR-plus-conversation-resolution requirement
  already forces the change to pass through a reviewable surface.
- **No required signed commits.** Squash merges performed through GitHub are
  signed by GitHub regardless, so the rule would mostly be redundant on the
  default branch, while adding friction to any future tooling or direct push that
  commits unsigned. With admin bypass in place the maintainer would skip the rule
  anyway. The provenance benefit is real but small for a solo public repo, and
  not worth the footgun.
- **Required status checks deferred to per-repo overrides.** A baseline default
  cannot name check contexts, because the contexts differ per repo (a Haskell
  library's CI matrix is not a CLI tool's). Requiring checks generically would
  mean requiring _named_ checks that do not exist everywhere. Each repo adds its
  own required checks as it is walked against this baseline, not here.
