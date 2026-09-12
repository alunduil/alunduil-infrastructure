<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Configure the TrueNAS config backup

A Cloud Sync task pushes dated tars of the TrueNAS configuration database to
Google Drive. Its pre-script,
[`scripts/truenas-config-backup.sh`](../../scripts/truenas-config-backup.sh),
builds a fresh tar before each transfer and prunes tars older than 90 days.

Follow this to stand up the backup on a rebuilt box, or run just the deploy
step after editing the pre-script.

Each tar holds `pwenc_secret`, the seed that decrypts every stored credential
in the database. Treat read access to the Drive folder as equivalent to root on
the NAS.

## Check for a competing cron job

Nothing else should write these tars. A cron job under **System → Advanced
Settings → Cron Jobs** that also writes them doubles the backup; delete it.

## Deploy the pre-script

Copy the script onto the box and mark it executable:

```sh
target=/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/config-backups/backup.sh
scp scripts/truenas-config-backup.sh "truenas:${target}"
ssh truenas chmod +x "${target}"
```

## Create a Cloud Sync task

In the TrueNAS UI under **Data Protection → Cloud Sync Tasks**, add (or
confirm) a task with these settings:

- **Credential**: the Google Drive backup credential.
- **Direction**: `PUSH`.
- **Remote folder**: `/truenas-config-backups`.
- **Directory/Files**:
  `/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/config-backups`.
- **Schedule**: daily at 03:00, after the 02:00 takeout pull so the two
  transfers don't contend for the box's two cores.
- **Pre-Script**:
  `/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/config-backups/backup.sh`.
