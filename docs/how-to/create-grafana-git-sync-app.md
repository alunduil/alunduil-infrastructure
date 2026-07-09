<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Git Sync GitHub App

A dedicated GitHub App that Grafana Git Sync authenticates through to
open dashboard pull requests. Separate from the deployer App in
[create-github-app.md](create-github-app.md): this one is installed on
only `alunduil-infrastructure`, so the private key handed to Grafana
Cloud can reach nothing else.

1. Create at <https://github.com/settings/apps/new> with:
   - Webhook: uncheck "Active"
   - Where can this GitHub App be installed: **Only on this account**
   - Repository permissions:
     - `Contents: Read and write` — read dashboards, push the branch
     - `Pull requests: Read and write` — open the sync PR
     - `Metadata: Read` (granted automatically)
2. After creation, on the App's settings page: note the **App ID**,
   then generate and download a private key (`.pem`).
3. Install the App on **only the `alunduil-infrastructure` repository**
   (Install App → Only select repositories). Open the installation's
   settings and note the **installation ID** — the numeric tail of the
   `.../installations/<id>` URL.

The App ID, installation ID, and `.pem` are inputs to `just bootstrap`,
which stores the key in Secret Manager and outputs the ids for the
alunduil layer:

```sh
export TF_VAR_grafana_git_sync_app_id=<app-id>
export TF_VAR_grafana_git_sync_app_installation_id=<installation-id>
export TF_VAR_grafana_git_sync_app_private_key="$(cat path/to/key.pem)"
```

Git Sync uses the `branch` workflow (the default-branch ruleset blocks
direct pushes to `main`), so dashboards edited in the Grafana UI arrive
as pull requests to review.

## Rotate

Generate a new private key on the App's settings page, delete the old
one, re-export `TF_VAR_grafana_git_sync_app_private_key`, and re-run
`just bootstrap`. The App ID and installation ID are unchanged.
