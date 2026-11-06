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

The workstation is the control machine. Ansible calls the `ssh` binary, so the
inventory supplies what `tailscale ssh` would otherwise handle:

- `tailscale nc` makes the connection, because the workstation's resolver can't
  resolve tailnet names.
- Tailscale's own known-hosts file supplies the host keys, so no operator
  accepts a key by hand. It lists each host under its fully qualified name with
  a trailing dot, so `ansible_host` uses that form.

Tailscale SSH authenticates the operator, so there's no separate key to manage.

### Tool versions

`ansible-core` is pinned twice, because two environments need it:

- This repo's `mise.toml` pins it for CI and the devcontainer, following #579.
- alunduil/alunduil-chezmoi#1137 pins it on the workstation, because operator
  runs use the host in the same way as `just bootstrap`.

The mise registry only offers `ansible-core` through `pypi:`, so this repo's pin
departs from #579's preference for `core` and `aqua`. The `pypi:` install needs
`python` and `uv` pinned beside it in `mise.toml`. `ansible-core` 2.22 needs
Python 3.13 or later on the control machine.

`ansible/requirements.yml` pins collections. Renovate tracks those pins and
the tools in `mise.toml`.

### Sensors

- `ansible-lint` runs as a prek hook.
- A CI job runs the playbook with `--check` against a Debian 12 container
  standing in for the NanoPi-NEO3, through the real inventory.

### Consequences

Good:

- `--check --diff` against a host detects drift.
- Terraform and host configuration live in one repo, with one review path.

Bad / accepted:

- The two `ansible-core` pins can differ between Renovate bumps.
- `mise.toml` and `mise.lock` are on `terraform-apply.yml`'s paths, so each
  tool bump waits for review and triggers an apply on merge.
- `mise lock` needs a real Python ahead of the mise shims on `PATH` to resolve
  the `pypi:` tool: `mise exec python uv -- mise lock`.
- The stand-in container is x86-64 and the NanoPi-NEO3 is arm64, so the job can't
  catch architecture-specific failures.
- Only the workstation can run a playbook against a host. A scheduled drift
  check would need CI to reach the tailnet.

- The tailnet's SSH rule uses `action: check`, so a run hangs with no prompt when
  the operator's login has lapsed. Running `tailscale ssh` first shows the login
  URL, and runs connect once the operator completes it.

### Open questions

- The SSH rule targets `autogroup:self`, which may stop matching once #514 tags
  the NanoPi-NEO3. That change may need an explicit SSH rule.

## More Information

The decision and scaffolding are tracked in #668. #671 adds the NanoPi-NEO3's
configuration and supersedes ADR 0002's configuration script.
