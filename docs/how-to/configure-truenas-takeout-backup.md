<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Configure the Google Takeout backup on TrueNAS

Google Takeout exports a full account archive to Google Drive on a
schedule; TrueNAS pulls those tarballs down and unpacks them. The pull
is a TrueNAS SCALE Cloud Sync task whose post-script,
[scripts/truenas-takeout-extract.sh](../../scripts/truenas-takeout-extract.sh),
extracts each tarball in `takeout/tarballs` into a per-export dated
directory and prunes extracted directories older than 180 days.

Follow this to stand the backup up on a rebuilt box, or run just the
deploy steps after editing the post-script.

## Prerequisite

Google Takeout is scheduled to export to Drive at `/Takeout` (set in the
Google account, outside TrueNAS).

## Deploy the post-script

1. Copy the repo copy to the box:

   ```sh
   scp scripts/truenas-takeout-extract.sh \
     truenas:/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/takeout/extract.sh
   ```

2. Mark it executable:

   ```sh
   ssh truenas chmod +x \
     /mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/takeout/extract.sh
   ```

## Create the Cloud Sync task

In the TrueNAS SCALE UI under **Data Protection → Cloud Sync Tasks**,
add (or confirm) a task with:

- **Credential**: the Google Drive backup credential.
- **Direction**: `PULL`, **Remote folder** `/Takeout`.
- **Directory/Files**:
  `/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/takeout/tarballs`.
- **Schedule**: daily at 02:00.
- **Fast list**: on.
- **Acknowledge abuse**: on — Drive flags Takeout archives, and the pull
  fails without it.
- **Post-Script**:
  `/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/takeout/extract.sh`.
