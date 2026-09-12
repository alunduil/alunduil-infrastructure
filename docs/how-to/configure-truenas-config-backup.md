<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Configure the TrueNAS config backup

Push dated tars of the TrueNAS configuration database to Google Drive on a
schedule.

## Prerequisites

- The `config-backups` dataset exists on the pool.
- A Google Drive credential is available to Cloud Sync.

## Deploy the pre-script

```sh
target=/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/config-backups/backup.sh
scp scripts/truenas-config-backup.sh "truenas:${target}"
ssh truenas chmod +x "${target}"
```

## Create a Cloud Sync task

Under **Data Protection → Cloud Sync Tasks**, add a task with these settings:

- **Credential**: the Google Drive backup credential.
- **Direction**: `PUSH`.
- **Remote folder**: `/truenas-config-backups`. Every tar holds
  `pwenc_secret`, so read access to this folder is equivalent to root on the
  NAS.
- **Directory/Files**:
  `/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/config-backups`.
- **Schedule**: daily at 03:00, after the 02:00 takeout pull so the two
  transfers don't contend for the box's two cores.
- **Pre-Script**:
  `/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/config-backups/backup.sh`.
