<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Configure remote hosts with Ansible over the tailnet

- Status: Accepted
- Date: 2026-11-06

## Context and Problem Statement

The NanoPi-NEO3 needs configuration and drift detection over the tailnet.
This repo already owns infrastructure state through Terraform, and remote
host configuration belongs next to it.
[ADR 0001](0001-use-talos-for-home-ad-hoc-services.md) covers the services
platform. Nothing yet covers general-purpose hosts.

alunduil/alunduil-chezmoi#842 sets the boundary. The workstation's own system
layer stays in alunduil-chezmoi, and that issue records what would trigger
moving it to a local playbook.

### Requirements

- **Reach.** Runs reach a host in another household with no inbound port open.
- **Drift detection.** A run reports differences without changing the host.
- **Pinning.** CI and the operator use pinned versions that Renovate tracks.

## Considered Options

- **Ansible from the workstation, over Tailscale SSH.** It meets all three
  requirements with no agent on the host and no separate operator key.
- **An idempotent script per host.** This is what
  [ADR 0002](0002-build-nanopi-neo3-recovery-image-with-armbian.md) chose for a
  single box. A script doesn't report drift.

## Decision Outcome

Chosen option: **Ansible, run from the workstation over Tailscale SSH.**

### Scope

Ansible covers remote general-purpose hosts, starting with the NanoPi-NEO3
(#671). Two things stay out:

- The workstation stays in alunduil-chezmoi.
- The `ha-terminal` role on the Home Assistant SSH add-on stays out, because
  Home Assistant manages it.

### Connection

The workstation is the control machine. Ansible calls plain `ssh`, so the
inventory connects through `tailscale nc` and trusts Tailscale's known-hosts
file. No operator accepts a host key by hand.

### Tool versions

`ansible-core` is pinned in each environment that runs it:

- This repo's `mise.toml` pins it for CI and the devcontainer, following #579.
- The `ansible-lint` hook pins it for its own environment. A Renovate group bumps
  it with `mise.toml`.
- alunduil/alunduil-chezmoi#1137 pins it on the workstation, because operator
  runs use the host's tools, as `just bootstrap` does.

The mise registry only offers `ansible-core` through `pypi:`, so this repo's pin
departs from #579's preference for `core` and `aqua`.

`ansible/requirements.yml` pins collections. Renovate tracks those pins and
the tools in `mise.toml`.

### Sensors

- `ansible-lint` runs as a prek hook.
- A CI job runs the playbook with `--check` through the real inventory against
  a container matching the NanoPi-NEO3's Debian point release and
  architecture, emulated with QEMU.

### Consequences

Good:

- `--check --diff` against a host detects drift.
- Terraform and host configuration live in one repo, with one review path.

Bad / accepted:

- The workstation's `ansible-core` pin can differ from this repo's between
  Renovate bumps.
- `mise.toml` and `mise.lock` are on `terraform-apply.yml`'s paths, so each
  tool bump waits for review and triggers an apply on merge.
- `mise lock` needs a real Python ahead of the mise shims on `PATH` to resolve
  the `pypi:` tool: `mise exec python uv -- mise lock`.
- Renovate moves the stand-in's Debian point release and apt moves the
  NanoPi-NEO3's, so the two can drift apart.
- Only the workstation can run a playbook against a host. A scheduled drift
  check would need CI to reach the tailnet.
- The tailnet's SSH rule uses `action: check`, so a run hangs with no prompt when
  the operator's login has lapsed.

### Open questions

- The SSH rule targets `autogroup:self`, which may stop matching once #514 tags
  the NanoPi-NEO3. That change may need an explicit SSH rule.
