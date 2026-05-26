<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the GitHub App

Required permissions and install scope are in
[reference/credentials.md#github-app](../reference/credentials.md#github-app).

1. Create at <https://github.com/settings/apps/new> with the
   permissions above. Uncheck the webhook "Active" box.
2. Install on your account with the install scope above.
3. Note the App ID, generate and download a private key (`.pem`).
4. Export `GH_APP_ID` and `GH_APP_PRIVATE_KEY` (the latter from the
   `.pem` contents) before running the secrets script.
