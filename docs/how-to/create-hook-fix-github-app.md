<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the hook-fix GitHub App

Pushes pre-commit hook fixes to Renovate branches in the managed
repositories. A push made with `GITHUB_TOKEN` doesn't trigger workflows,
so the required checks wouldn't re-run on the fixed commit. A push made
with an App token does. The `renovate` ruleset lets this App and Renovate
push to `renovate/**` branches, and no one else.

1. Create at <https://github.com/settings/apps/new> with:
   - **GitHub App name**: any name unique across GitHub, for example
     `alunduil-hook-fix`. Display only.
   - **`Homepage URL`** (required): the repo,
     `https://github.com/alunduil/alunduil-infrastructure`.
   - **Webhook**: uncheck **Active**.
   - Leave the user-authorization checkboxes under `Callback URL` at
     their defaults. This App authenticates as an installation, not a
     user.
   - Repository permissions (everything else **No access**):
     - `Contents: Read and write`
     - `Metadata: Read-only` (granted automatically)

     Leave `Workflows` at **No access**. A fix that touches
     `.github/workflows/` then fails to push instead of landing past
     review.
   - Where can this GitHub App be installed: **Only on this account**.
2. On the App's **General** page: note the **App ID**, then under
   **Private keys** generate and download one (`.pem`). GitHub only
   shows it once, so regenerate it if lost.
3. **Install App** → **Install** on your account → **All
   repositories**, so a repo that turns on `renovate_automerge` later
   needs no change here.
4. Put the App ID in `hook_fix_actor` in
   `terraform/modules/github_repository/main.tf`, so the `renovate`
   ruleset lists the App as a bypass actor.

## Set the Actions secrets

`scripts/configure-github-secrets.sh` writes `HOOK_FIX_APP_ID` and
`HOOK_FIX_APP_PRIVATE_KEY` to every repo with a `renovate` ruleset that
lacks them. Run it after each apply that sets `renovate_automerge = true`
on a repo:

```sh
export HOOK_FIX_APP_ID=<app-id>
export HOOK_FIX_APP_PRIVATE_KEY_FILE=<path-to-key.pem>

scripts/configure-github-secrets.sh
```

Without the variables the script prompts for each value. With them, it
also overwrites repos that already hold the secrets, which is how a new
key reaches every repo.
