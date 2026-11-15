<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Configure the NanoPi-NEO3 with Ansible

- Status: Accepted
- Date: 2026-11-15

## Context and Problem Statement

[ADR 0002](0002-build-nanopi-neo3-recovery-image-with-armbian.md) chose an
idempotent shell script as the NanoPi-NEO3's single description, run inside the
image build's `chroot` and over SSH afterwards. It named when to change course:
"Escalate to Ansible … when drift detection is worth a control machine for one
host."

[ADR 0005](0005-configure-remote-hosts-with-ansible.md) brought Ansible and a
control machine into this repo for remote hosts. The cost ADR 0002 avoided is
now paid, and a second configuration mechanism for one host would be the extra
machinery. Neither the script nor `userpatches/` exists yet, so changing course
discards no work.

This record supersedes ADR 0002's "Configuring the box after boot" section.
ADR 0002's image-build decision stands: Armbian's build framework, a public
release, and no secrets in the artifact.

## Considered Options

- **The script, as ADR 0002 decided.** It runs in both places, but it doesn't
  report drift.
- **The playbook, with a minimal image.** The image bakes only what SSH needs,
  and the playbook does everything else.
- **The playbook, also run in the image's `chroot`.** It keeps ADR 0002's
  driver that anything settable without a secret is configured at build time.
  The role then has to converge without systemd running and without
  credentials, and gets tested in both contexts.

## Decision Outcome

Chosen option: **the playbook, with a minimal image.**

### What the image carries

Baked in: the operator's public key in root's `authorized_keys`, password
authentication disabled, the first-login flag cleared, the hostname, and DHCP.
That's what the recovery SSH session needs, and recovery needs that session
anyway to supply credentials. Tailscale, Grafana Alloy and unattended upgrades
move from the image to the playbook.

ADR 0002's list of what's deliberately absent stands.

### Credentials at run time

No credential is committed, and the playbook asks for one only when the box
needs it:

- The Tailscale auth key is prompted when Tailscale isn't logged in.
- The heartbeat URL is prompted when the heartbeat unit is missing.
- The Alloy token is read from Secret Manager with `gcloud` on the control
  machine.

Routine and drift runs stay non-interactive.

### The backup

The playbook replaces the hourly `rclone` sync of `/etc` and `/home` as the way
to recover the box. The sync stops, and its Drive copy is deleted. This settles
the question ADR 0002 left open.

### The recovery procedure

Step 3 of ADR 0002's procedure becomes: the operator runs the playbook limited
to the NanoPi-NEO3, with the inventory's address and port overridden to the
router's forwarded port, and supplies the prompted credentials. The other steps
stand.

### Consequences

Good:

- `--check --diff` against the box detects a change made by hand and never
  committed, the gap ADR 0002 accepted.
- The box has one description in one tool, shared with ADR 0005's other hosts.
- The image changes only when the SSH bootstrap does.

Bad / accepted:

- A freshly flashed card does nothing useful until the playbook runs. ADR 0002's
  recovery already required that SSH session, so recovery gains no step.
- The image and the running box are two descriptions, but the image's part is
  five facts the playbook doesn't contradict.
- The box has no backup. Anything on it that the playbook doesn't manage is lost
  when a card is replaced.

## More Information

The role is tracked in #671, and the image build in #261.
