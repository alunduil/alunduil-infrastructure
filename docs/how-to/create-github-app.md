<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the GitHub App

Authenticates the `integrations/github` Terraform provider in CI. The
workflow exchanges App ID + private key for short-lived installation
tokens via OIDC.

1. Create at <https://github.com/settings/apps/new> with the following
   repository permissions:
   - `Administration: Read and write`
   - `Contents: Read and write`
   - `Metadata: Read` (granted automatically)
   - `Pages: Read and write`

   Uncheck the webhook "Active" box.
2. Install on your account with "All repositories" so new repos are
   picked up without re-issuing credentials.
3. Note the App ID, generate and download a private key (`.pem`).
4. Export `GH_APP_ID` and `GH_APP_PRIVATE_KEY` (the latter from the
   `.pem` contents) before running the secrets script.
