<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Bake only SSH access into the NanoPi-NEO3 image

- Status: Accepted
- Date: 2026-11-15

## Context and Problem Statement

[ADR 0002](0002-build-nanopi-neo3-recovery-image-with-armbian.md) baked
everything settable without a secret into the NanoPi-NEO3's recovery image,
including Tailscale, Grafana Alloy and unattended upgrades. A single script
configured both the image and the running box.

[ADR 0005](0005-configure-remote-hosts-with-ansible.md) replaced that script
with an Ansible playbook run from the workstation, so the image's contents need
choosing again. Neither `userpatches/` nor the script exists yet, so no work is
lost.

## Considered Options

- **Run the playbook in the image's `chroot` too.** Anything settable without a
  secret stays configured at build time. The role must converge without
  systemd running and without credentials, and needs testing in both contexts.
- **Bake only what SSH needs.** The playbook does everything else during the
  recovery SSH session, which recovery already needs to supply credentials.

## Decision Outcome

Chosen option: **bake only what SSH needs.**

Baked in: the operator's public key in root's `authorized_keys`, password
authentication disabled, the first-login flag cleared, the hostname, and DHCP.
Tailscale, Grafana Alloy and unattended upgrades move from the image to the
playbook.

ADR 0002's list of what's deliberately absent stands.

### Consequences

Good:

- The role runs in one context, against a booted host.
- The playbook manages none of the five baked settings, so the image and the
  playbook can't contradict each other.

Bad / accepted:

- A freshly flashed card does nothing useful until the playbook runs. Recovery
  already needed an SSH session to supply credentials, so it gains no step.

## More Information

Issue #671 tracks the role, and #261 the image build.
