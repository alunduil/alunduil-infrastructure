<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Git Sync GitHub App

A dedicated GitHub App Grafana Git Sync uses to open dashboard pull
requests. Unlike the deployer App in
[create-deployer-github-app.md](create-deployer-github-app.md), install
this one on only `alunduil-infrastructure`, so the private key handed to
Grafana Cloud can reach nothing else.

1. Create at <https://github.com/settings/apps/new> with:
   - **GitHub App name**: `Grafana Cloud GitHub Sync`. The bootstrap
     prompts ask for it by this name; change one and change the other.
     App names are unique across GitHub, so a rebuild needs the old App
     deleted first.
   - **Homepage URL** (required): the repo,
     `https://github.com/alunduil/alunduil-infrastructure`.
   - **Webhook**: uncheck "Active" (otherwise it demands a URL).
   - Leave the user-authorization checkboxes under Callback URL
     (Expire user authorization tokens, Request user authorization on
     install, Enable Device Flow) at their defaults. This App
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

`just bootstrap` prompts for the App ID, installation ID, and `.pem` path
the first time it runs. Set these beforehand to answer without the
prompt:

```sh
export GIT_SYNC_APP_ID=<app-id>
export GIT_SYNC_APP_INSTALLATION_ID=<installation-id>
export GIT_SYNC_APP_PRIVATE_KEY_FILE=<path-to-key.pem>
```

Each value goes into Secret Manager, and later runs skip it. Shred the
`.pem` once `terraform/alunduil/` has applied; nothing reads it again. To
replace the key, see
[rotate-git-sync-app-key.md](rotate-git-sync-app-key.md).
