<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Rotate the Git Sync App's private key

Replaces the private key Grafana Cloud signs with to generate installation
tokens for `alunduil-infrastructure`. The App ID and installation ID stay the
same.

You need admin on the App, and permission to add and destroy secret versions in
the `alunduil` project.

`just bootstrap` writes each Git Sync secret once and skips it afterwards, so
rotation goes through `gcloud` rather than a re-run. An App holds two private
keys at once: leave the old one in place until step 5, so Git Sync keeps
authenticating throughout.

1. Generate a second private key under **Private keys** on the App's General
   tab.

2. Add it as a new secret version:

   ```sh
   gcloud secrets versions add grafana-git-sync-app-private-key \
     --project alunduil \
     --data-file ~/Downloads/<new-key>.private-key.pem
   ```

3. Increment `secure_version` in `terraform/alunduil/grafana.tf` and merge the
   change, which runs the apply in CI. The `secure` block is write-only, so the
   provider re-sends the key only when that counter moves; step 2 on its own
   leaves the connection signing with the old key.

4. Confirm the dashboards repository still syncs, under **Administration >
   Provisioning** in Grafana. A successful apply proves only that Grafana
   accepted the key; the sync is what proves GitHub accepts it.

5. Delete the old key on the App's General tab.

6. Destroy the superseded secret version, which stays readable until you do:

   ```sh
   gcloud secrets versions destroy <N> \
     --secret grafana-git-sync-app-private-key \
     --project alunduil
   ```

7. Shred the downloaded `.pem`.
