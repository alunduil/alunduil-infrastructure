<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Retire the NanoPi-NEO3 backup

- Status: Accepted
- Date: 2026-11-15

## Context and Problem Statement

The NanoPi-NEO3 syncs `/etc` and `/home` to Google Drive hourly with `rclone`.
[ADR 0002](0002-build-nanopi-neo3-recovery-image-with-armbian.md) took the sync
out of recovery and left its future open.

The Ansible playbook from
[ADR 0005](0005-configure-remote-hosts-with-ansible.md) now describes the box,
so restoring `/etc` no longer configures a card. The `/etc` copy also puts the
box's credentials on Drive.

## Considered Options

- **Keep the sync as it is.** Drive keeps a copy of the credentials, and the box
  keeps a Drive credential of its own.
- **Back up `/home` only.** Drive loses the credentials, but the box keeps
  `rclone` and a Drive credential, which recovery must re-supply to a new card.
- **No backup.** The playbook and the image describe the whole box.

## Decision Outcome

Chosen option: **no backup.** The exit node's one service keeps nothing in
`/home`, so a `/home` backup preserves nothing recovery needs.

The playbook stops the sync and removes `rclone`'s configuration. The operator
deletes the Drive copy and revokes the box's Drive credential, unless TrueNAS's
Cloud Sync tasks share it.

### Consequences

Good:

- The box's credentials exist only on the box and at their sources.
- A lost card grants no Drive access.

Bad / accepted:

- A card replacement loses anything the playbook doesn't manage.
- Deleting the Drive copy can't be undone.

## More Information

Issue #671 tracks the removal and the Drive cleanup.
