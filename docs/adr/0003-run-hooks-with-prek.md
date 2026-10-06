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
calls `astral-sh/setup-uv` and `actions/cache`, both pinned by SHA.
That compliance holds only while its maintainers keep pinning.
Upstream `pre-commit/action` is maintenance-only and points at hosted
pre-commit.ci, which can't run hooks that need system binaries such as
`terraform`, `just`, `cabal`, or `pnpm`.

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
compliance comes from the action's structure. Every hook runs under
`prek` unchanged.

The config stays in YAML because Renovate has a `pre-commit` manager
that reads `.pre-commit-config.yaml`, and no manager for `prek.toml`.
YAML also keeps the decision reversible: returning to `pre-commit` is
an action swap and a workstation reinstall, with no config rewrite.

### Migration constraints

- Keep config files free of prek-only keys and arguments such as
  `repo: builtin`.
- Pin the action's `prek-version` input. It defaults to `latest`.
  Annotate the pin so Renovate tracks it.
- Keep each CI job's `name:` unchanged. Branch protection matches
  required checks by job name.
- Run `prek install` in place of `pre-commit install`. It replaces the
  Git shim, including `commit-msg` for repos that set
  `default_install_hook_types`.

### Hook compatibility

The per-hook matrix is on #681.

- **`python`, `node`, `golang`**: `prek` installs the language
  runtime, covering `reuse`, `shfmt`, `markdownlint-cli2`, and `vale`.
- **`script`**: `pre-commit-terraform` runs with the runner's
  `terraform`, as under `pre-commit`.
- **`system`, `haskell`**: `repo: local` hooks call tools on the
  runner, such as `just`, `pnpm`, and `cabal`, as under `pre-commit`.
- **`docker_image`**: runs through the host's container engine.

The fast path supports every argument the config files pass to
`pre-commit/pre-commit-hooks`: `--maxkb`, `--fix=lf`,
`--markdown-linebreak-ext`, `--branch`, and `--unsafe`. Two hooks
behave differently from the pinned Python versions:

- `check-yaml` accepts unknown YAML tags, which the Python hook
  rejects. Repos passing `--unsafe` already skipped that check.
- `check-json` rejects duplicate object keys, which the Python hook
  accepts.

Setting `PREK_NO_FAST_PATH=1` runs the pinned Python hooks instead.

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
- `check-yaml` and `check-json` change behaviour on the fast path.
- `prek` has one maintainer. Its author has about 1,450 commits and
  the next human contributor has 40. Keeping the YAML config is the
  mitigation.
- `prek` is pre-1.0, at 0.5.5, with no 1.0 timeline. The maintainer
  aims to add features without breaking `pre-commit` compatibility
  ([j178/prek#1211](https://github.com/j178/prek/issues/1211)), and
  the breaking changes through 0.5.0 removed prek-only aliases and
  edge features, not standard config behaviour. The Rust hooks can
  still drift from the Python ones they replace. Pinning
  `prek-version` turns each release into a Renovate PR whose CI runs
  every hook.

## More Information

The decision and research are tracked in #681. Related pinning work
is alunduil/alunduil-chezmoi#448 and alunduil/alunduil-chezmoi#449.
