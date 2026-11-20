<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the release gate GitHub App

The release gate answers GitHub's deployment protection rule from a
Cloudflare Worker. This App is the identity it answers as. Register it
for this alone: its key approves deployments, so it shouldn't also be
able to create the tags they run from.

1. Create at <https://github.com/settings/apps/new> with:
   - **GitHub App name**: `alunduil-release-gate`.
   - **Description**: `Approves a deployment only when its commit is
     on the repository's default branch.`
   - **`Homepage URL`** (required): `https://github.com/alunduil/release-gate`.
   - **Webhook**: leave **Active** checked. Set **Webhook URL** to the
     Worker's `workers.dev` address,
     `https://<worker>.<subdomain>.workers.dev`. Workers & Pages in the
     Cloudflare dashboard shows the account's subdomain. Leave **Webhook
     secret** empty for now.
   - Leave the user-authorization checkboxes under `Callback URL` at
     their defaults. This App authenticates as an installation, not a
     user.
   - Repository permissions (everything else **No access**):
     - `Actions: Read-only`
     - `Deployments: Read and write`
     - `Metadata: Read-only` (granted automatically)
   - **Subscribe to events**: `Deployment protection rule` only.
   - Where can this GitHub App be installed: **Only on this account**.
2. On the App's **General** page: note the **App ID**, then under
   **Private keys** generate and download one (`.pem`). GitHub only
   shows it once, so regenerate it if lost.
3. **Install App** → **Install** on your account → **All
   repositories**, so a new publish environment needs no change here.

## Store the private key

`just bootstrap` prompts for the private key and stores it in Secret
Manager. To store it without a full bootstrap:

```sh
just configure-release-gate
```

To roll out a new key, supply its path. A supplied key overwrites the
stored one:

```sh
export RELEASE_GATE_APP_PRIVATE_KEY_FILE=<path-to-key.pem>

just configure-release-gate
```

## Set the webhook secret

`just bootstrap` generates the webhook secret. Copy it into the App after
the bootstrap apply, and again whenever bootstrap replaces it:

```sh
gcloud secrets versions access latest --secret=release-gate-webhook-secret --project=alunduil
```

Paste the output into **Webhook secret** on the App's **General** page
and save.
