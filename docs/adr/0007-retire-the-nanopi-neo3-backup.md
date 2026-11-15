<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Retire the NanoPi-NEO3 backup

- Status: Accepted
- Date: 2026-11-15

## Context and Problem Statement

The NanoPi-NEO3 syncs `/etc` and `/home` to Google Drive hourly with `rclone`.
[ADR 0002](0002-build-nanopi-neo3-recovery-image-with-armbian.md) took the sync
out of recovery and left its future as a separate question. This record answers
it.

Two facts frame the answer:

- The Ansible playbook from
  [ADR 0005](0005-configure-remote-hosts-with-ansible.md) describes the box, so
  restoring `/etc` is no longer how a card gets configured.
- The `/etc` copy carries the box's credentials, so Drive holds them in a second
  place.

## Considered Options

- **Keep the sync as it is.** Drive keeps a copy of the credentials, and the box
  keeps a Drive credential of its own.
- **Back up `/home` only.** This drops the credentials from Drive, but keeps
  `rclone` and a Drive credential on the box. A replacement card needs that
  credential re-supplied during recovery.
- **No backup.** The playbook and the image are the box's whole description.

## Decision Outcome

Chosen option: **no backup.** The exit node's one service keeps nothing in
`/home`, so a `/home` backup preserves no state recovery needs.

The playbook stops the sync and removes `rclone`'s configuration. The Drive copy
is deleted, and the Drive credential the box held is revoked.

### Consequences

Good:

- The box's credentials exist only on the box and at their sources.
- The box holds no Drive credential, so a lost card grants no Drive access.

Bad / accepted:

- Anything on the box that the playbook doesn't manage is lost when a card is
  replaced.
- Deleting the Drive copy can't be undone.

## More Information

The removal and the Drive cleanup are tracked in #671.
