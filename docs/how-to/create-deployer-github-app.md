<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the deployer GitHub App

Authenticates the `integrations/github` Terraform provider in CI. The
workflow exchanges App ID + private key for short-lived installation
tokens via OIDC.

1. Create at <https://github.com/settings/apps/new> with:
   - **GitHub App name**: any name unique across GitHub, e.g.
     `alunduil-infra-deployer`. Display only.
   - **Homepage URL** (required): the repo,
     `https://github.com/alunduil/alunduil-infrastructure`.
   - Webhook: uncheck "Active"
   - Leave the user-authorization checkboxes under Callback URL
     (Expire user authorization tokens, Request user authorization on
     install, Enable Device Flow) at their defaults — the deployer
     authenticates as an installation, not a user.
   - Where can this GitHub App be installed: **Only on this account**
     (the App's private key mints installation tokens for every
     account the App is installed on, so limiting installation to
     your own account keeps the blast radius matched to what this
     repo actually manages)
   - Repository permissions:
     - `Administration: Read and write`
     - `Contents: Read and write`
     - `Metadata: Read` (granted automatically)
     - `Pages: Read and write`
2. After creation, on the App's settings page: note the App ID, then
   generate and download a private key (`.pem`).
3. Install the App on your personal account with "All repositories"
   so new repos are picked up without re-issuing credentials.

The App ID and the `.pem` file are inputs to
`scripts/configure-github-secrets.sh` — pass them via `GH_APP_ID` and
`GH_APP_PRIVATE_KEY_FILE` (path to the `.pem`) environment variables,
or let the script prompt for them.
