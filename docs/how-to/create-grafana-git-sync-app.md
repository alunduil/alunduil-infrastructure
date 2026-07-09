<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Git Sync GitHub App

A dedicated GitHub App that Grafana Git Sync authenticates through to
open dashboard pull requests. Separate from the deployer App in
[create-github-app.md](create-github-app.md): this one is installed on
only `alunduil-infrastructure`, so the private key handed to Grafana
Cloud can reach nothing else.

1. Create at <https://github.com/settings/apps/new> with:
   - **GitHub App name**: any name unique across GitHub, e.g.
     `alunduil-infra-git-sync`. Display only; Terraform never uses it.
   - **Homepage URL** (required): the repo,
     `https://github.com/alunduil/alunduil-infrastructure`.
   - **Webhook**: uncheck "Active" (otherwise it demands a URL).
   - Leave the user-authorization checkboxes under Callback URL
     (Expire user authorization tokens, Request user authorization on
     install, Enable Device Flow) at their defaults — this App
     authenticates as an installation, not a user, so none apply.
   - Repository permissions (everything else "No access"):
     - `Contents: Read and write` — read dashboards, push the branch
     - `Pull requests: Read and write` — open the sync PR
     - `Metadata: Read-only` (granted automatically)
   - Where can this GitHub App be installed: **Only on this account**
2. On the App's **General** page: note the **App ID**, then under
   **Private keys** generate and download one (`.pem`). GitHub only
   shows it once — regenerate if lost.
3. **Install App** → **Install** on your account → **Only select
   repositories** → `alunduil-infrastructure`. The installation page
   URL is `https://github.com/settings/installations/<id>`; that `<id>`
   is the **installation ID** (reachable later via Settings →
   Applications → Installed GitHub Apps → Configure).

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
