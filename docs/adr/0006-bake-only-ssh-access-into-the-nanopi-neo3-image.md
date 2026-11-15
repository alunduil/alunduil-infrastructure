<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Bake only SSH access into the NanoPi-NEO3 image

- Status: Accepted
- Date: 2026-11-15

## Context and Problem Statement

[ADR 0002](0002-build-nanopi-neo3-recovery-image-with-armbian.md) baked
everything settable without a secret into the NanoPi-NEO3's recovery image,
including Tailscale, Grafana Alloy and unattended upgrades. One script ran in the
image build's `chroot` and over SSH afterwards, so the image and the running box
shared a single description.

[ADR 0005](0005-configure-remote-hosts-with-ansible.md) replaced that script
with an Ansible playbook run from the workstation. This record decides what the
image carries now that the playbook configures the box.

Neither `userpatches/` nor the script exists yet, so changing the answer
discards no work.

## Considered Options

- **Run the playbook in the image's `chroot` too.** This keeps ADR 0002's
  driver that anything settable without a secret is configured at build time.
  The role then has to converge without systemd running and without
  credentials, and gets tested in both contexts.
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
- The image's five baked settings are ones the playbook doesn't manage, so
  the two descriptions can't contradict each other.

Bad / accepted:

- A freshly flashed card does nothing useful until the playbook runs. ADR 0002's
  recovery already required that SSH session, so recovery gains no step.

## More Information

The role is tracked in #671, and the image build in #261.
