<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the hook-fix self-test GitHub App

Opens the throwaway `renovate/hook-fix-selftest-*` pull requests that
`renovate-config`'s self-test runs `fix-renovate-hooks.yml` against.
Events from `GITHUB_TOKEN` don't start workflows, and
`fix-renovate-hooks.yml` skips the hook-fix App's own events, so neither
can open them.

1. Create at <https://github.com/settings/apps/new> with:
   - **GitHub App name**: `alunduil-hook-fix-selftest`. A pull request's
     timeline credits it to `alunduil-hook-fix-selftest[bot]`, which
     tells a reviewer it's a test. Renaming it means renaming `APP_NAME`
     in `scripts/configure-hook-fix-selftest-secrets.sh` too.
   - **Description**: `Opens throwaway pull requests in renovate-config
     that test the hook-fix workflow end to end.`
   - **`Homepage URL`** (required): the repo,
     `https://github.com/alunduil/alunduil-infrastructure`.
   - **Webhook**: uncheck **Active**.
   - Leave the user-authorization checkboxes under `Callback URL` at
     their defaults. This App authenticates as an installation, not a
     user.
   - Repository permissions (everything else **No access**):
     - `Contents: Read and write`
     - `Pull requests: Read and write`
     - `Workflows: Read and write`
     - `Metadata: Read-only` (granted automatically)

     `Workflows` lets the self-test plant a fault under
     `.github/workflows/`, the case the hook-fix App must fail to push.
   - Where can this GitHub App be installed: **Only on this account**.
2. On the App's **General** page: note the **App ID**, then under
   **Private keys** generate and download one (`.pem`). GitHub only
   shows it once, so regenerate it if lost.
3. **Install App** → **Install** on your account → **Only select
   repositories** → `renovate-config`.

## Store the credentials

The self-test reads the App ID and private key from Secret Manager.
`just bootstrap` prompts for both. To store them without a full
bootstrap:

```sh
just configure-hook-fix-selftest
```

To roll out a new key, set both variables. Supplied values overwrite the
stored ones:

```sh
export HOOK_FIX_SELFTEST_APP_ID=<app-id>
export HOOK_FIX_SELFTEST_APP_PRIVATE_KEY_FILE=<path-to-key.pem>

just configure-hook-fix-selftest
```
