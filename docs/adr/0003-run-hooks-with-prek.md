<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Run hooks with prek instead of pre-commit

- Status: Accepted
- Date: 2026-10-05

## Context and Problem Statement

Eleven repos across the `alunduil` and `dungeon-studio` accounts share
one hook suite convention: a `.pre-commit-config.yaml` run on
workstations by `pre-commit` and in CI by a GitHub Action.

Enabling `sha_pinning_required` on the managed repos (#372) turned CI
red in eight repos at once. The ruleset resolves action refs
transitively, and `pre-commit/action@v3.0.1` calls an unpinned
`actions/cache@v4` from inside its composite, so jobs failed during
_Set up job_ before any step ran.

The stopgap swapped in `tox-dev/action-pre-commit-uv`. Its composite
calls `astral-sh/setup-uv` and `actions/cache`, both pinned by SHA
today. That compliance holds only while its maintainers keep pinning.
Upstream `pre-commit/action` is maintenance-only and points at hosted
pre-commit.ci, which can't run hooks that need system binaries such as
`terraform`, `just`, `cabal`, or `pnpm`.

This record decides which tool runs the hook suites, in CI and on
workstations.

### Requirements

- **Pinning.** The CI action passes `sha_pinning_required` by
  construction, without relying on nested actions staying pinned.
- **Coverage.** Every existing hook runs. That includes `repo: local`
  hooks with `language: system`, which call tools installed on the
  runner.
- **Renovate.** Renovate keeps bumping hook revisions.

## Considered Options

- **Stay on `pre-commit` with `tox-dev/action-pre-commit-uv`.** It
  meets coverage and Renovate. It meets pinning only while its
  maintainers keep pinning their nested actions.
- **`prek` in CI only.** It meets all three requirements, but
  workstations and CI would run different implementations of the same
  hooks. `prek` replaces the `pre-commit/pre-commit-hooks` entries
  with Rust implementations, called its automatic fast path. The
  fast-path differences listed under Hook compatibility would let a
  commit pass locally and fail in CI, or the reverse.
- **`prek` in CI and on workstations.** It meets all three
  requirements with one implementation everywhere.

## Decision Outcome

Chosen option: **`prek` in CI and on workstations, keeping
`.pre-commit-config.yaml` as the config file.**

`j178/prek-action` runs as `node24` with no nested `uses:`, so pinning
compliance comes from the action's structure. Every hook in the
inventory below runs under `prek` unchanged.

The config stays in YAML because Renovate has a `pre-commit` manager
that reads `.pre-commit-config.yaml`, and no manager for `prek.toml`.
YAML also keeps the decision reversible: returning to `pre-commit` is
an action swap and a workstation reinstall, with no config rewrite.
For the same reason, config files avoid prek-only keys and arguments
such as `repo: builtin`.

### Migration constraints

- Add `j178/prek-action@*` to the baseline allowed actions in
  `terraform/modules/github_repository/main.tf` before any managed repo
  calls it. Drop `tox-dev/action-pre-commit-uv@*` once none does.
- Pin the action's `prek-version` input. It defaults to `latest`.
  Annotate the pin so Renovate tracks it.
- Keep each CI job's `name:` unchanged. Branch protection matches
  required checks by job name.
- Run `prek install` in place of `pre-commit install`. It replaces the
  Git shim, including `commit-msg` for repos that set
  `default_install_hook_types`.

### Hook compatibility

Inventory taken on 2026-10-05 across the eleven repos' config files.
Each hook's language comes from its repo's `.pre-commit-hooks.yaml` at
the pinned `rev`. The count after each source is the number of repos
using it.

- **`python`**, run in a Python environment `prek` manages:
  `pre-commit/pre-commit-hooks` (11), `adrienverge/yamllint` (6),
  `fsfe/reuse-tool` (6), `shellcheck-py/shellcheck-py` (5),
  `scop/pre-commit-shfmt` (4), `compilerla/conventional-pre-commit`
  (4, `commit-msg` stage), `tombi-toml/tombi-pre-commit` (2, one hook
  on the `manual` stage), `zizmorcore/zizmor-pre-commit` (2), and
  one repo each for `python-jsonschema/check-jsonschema`,
  `Yelp/detect-secrets`, `ComPWA/taplo-pre-commit`,
  `astral-sh/ruff-pre-commit`, `pre-commit/mirrors-mypy`,
  `jendrikseipp/vulture`,
  `macisamuele/language-formatters-pre-commit-hooks`, and
  `tweag/FawltyDeps`.
- **`node`**, run on a Node release `prek` downloads:
  `renovatebot/pre-commit-hooks` (10), `DavidAnson/markdownlint-cli2`
  (8), and `igorshubovych/markdownlint-cli` (1).
- **`golang`**, built with a Go release `prek` downloads:
  `errata-ai/vale` and `vale-cli/vale` (10 together), and
  `rhysd/actionlint` (8).
- **`docker_image`**, run through the host's container engine:
  `actionlint-docker` from `rhysd/actionlint`,
  `koalaman/shellcheck-precommit`, and `hadolint/hadolint` (1 each).
- **`script`**, which runs the hook repo's own script:
  `antonbabenko/pre-commit-terraform` (2), using the runner's
  `terraform` and `trivy`.
- **`system`**, which runs `entry` directly, as `pre-commit` does:
  `repo: local` hooks in 10 repos calling `pnpm`, `cargo`, `lychee`,
  `just`, `fourmolu`, `hlint`, and repo scripts.
- **`haskell`**, built with the runner's `cabal` and `ghc`, as
  `pre-commit` does: `repo: local` hooks in `network-arbitrary`.

The fast path supports every argument the config files pass to
`pre-commit/pre-commit-hooks`: `--maxkb`, `--fix=lf`,
`--markdown-linebreak-ext`, `--branch`, and `--unsafe`. Two hooks
behave differently from the pinned Python versions:

- `check-yaml` accepts unknown YAML tags, which the Python hook
  rejects. Repos passing `--unsafe` already skipped that check.
- `check-json` rejects duplicate object keys, which the Python hook
  accepts.

Setting `PREK_NO_FAST_PATH=1` runs the pinned Python hooks instead.

### Risks accepted

- **One maintainer.** The project's author has about 1,450 commits.
  The next human contributor has 40. Keeping the YAML config is the
  mitigation, because leaving costs an action swap.
- **Pre-1.0 churn.** `prek` is at 0.5.5. Minor releases may change
  behaviour, and the Rust hooks can drift further from the Python ones
  they replace. Pinning `prek-version` turns each change into a
  reviewed Renovate PR.

### Consequences

Good:

- Hook runs get faster, on workstations most noticeably, from the Rust
  fast path and language installs shared across hooks.
- `prek update` adds `--cooldown-days` and detects impostor commits
  behind pinned revisions. These help manual updates; Renovate remains
  the update path.

Bad / accepted:

- Each repo's CI, contributor setup docs, and the workstation install
  all change.
- The two fast-path behaviour differences under Hook compatibility.

Neutral:

- The config format and hook revisions are unchanged.

## More Information

The decision and research are tracked in #681. Related pinning work
is alunduil/alunduil-chezmoi#448 and alunduil/alunduil-chezmoi#449.
