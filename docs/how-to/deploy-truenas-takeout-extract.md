<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Deploy the TrueNAS Takeout extract.sh post-script

[scripts/truenas-takeout-extract.sh](../../scripts/truenas-takeout-extract.sh)
is the post-script for the Google Takeout → Drive Cloud Sync task on
TrueNAS: after each pull it extracts the tarballs in `takeout/tarballs`
into per-export dated directories and prunes extracted directories older
than 180 days. It runs on the NAS, so the repo copy has to be pushed to
the box to take effect.

Run this after editing the script here, or to restore it onto a rebuilt
box.

## Deploy

1. Copy the repo copy to the path the Cloud Sync task invokes:

   ```sh
   scp scripts/truenas-takeout-extract.sh \
     truenas:/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/takeout/extract.sh
   ```

2. Mark it executable:

   ```sh
   ssh truenas chmod +x \
     /mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/takeout/extract.sh
   ```

3. On a rebuilt box only, recreate the wiring in the TrueNAS SCALE UI
   under **Data Protection → Cloud Sync Tasks**: the Google Takeout
   task's **Post-Script** invokes
   `/mnt/volume-7e99f60b-f655-4fd1-b03a-099d965d2e30/takeout/extract.sh`.
   An existing task already points there, so a script update needs only
   steps 1–2.
