<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the hook-fix GitHub App

Pushes pre-commit hook fixes to Renovate branches in the managed
repositories. A push made with `GITHUB_TOKEN` doesn't trigger workflows,
so the required checks wouldn't re-run on the fixed commit. A push made
with an App token does.

1. Create at <https://github.com/settings/apps/new> with:
   - **GitHub App name**: `alunduil-hook-fix`. A pull request's
     timeline credits its pushes to `alunduil-hook-fix[bot]`, which tells
     a reviewer they aren't Renovate's.
   - **Description**: `Pushes pre-commit hook fixes to Renovate
     branches, so the required checks run on the fixed commit.`
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

Run this after each apply that sets
`required_status_checks.renovate_automerge = true` on a repo. It
writes `HOOK_FIX_APP_ID` and `HOOK_FIX_APP_PRIVATE_KEY` to every repo
with a `renovate` ruleset that lacks them, prompting for each value:

```sh
just configure-hook-fix
```

To roll out a new key, set both variables first. Every repo's copy is
then overwritten:

```sh
export HOOK_FIX_APP_ID=<app-id>
export HOOK_FIX_APP_PRIVATE_KEY_FILE=<path-to-key.pem>

just configure-hook-fix
```
