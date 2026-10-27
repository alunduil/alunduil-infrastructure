<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Grafana GitHub data source App

A read-only GitHub App the Grafana GitHub data source authenticates as.
The delivery-metrics dashboards in
[delivery-metrics.md](../reference/delivery-metrics.md) query GitHub
through it.

## Create the App

1. Create at <https://github.com/settings/apps/new> with:
   - **GitHub App name**: `alunduil-grafana-github`. Renaming it means
     renaming `APP_NAME` in `scripts/configure-grafana-github-secrets.sh`
     too.
   - **`Homepage URL`** (required): the repo,
     `https://github.com/alunduil/alunduil-infrastructure`.
   - **Webhook**: uncheck **Active**.
   - Leave the user-authorization checkboxes under `Callback URL` at
     their defaults. This App authenticates as an installation, not a
     user.
   - Repository permissions (everything else **No access**):
     - `Actions: Read-only`
     - `Contents: Read-only`
     - `Issues: Read-only`
     - `Metadata: Read-only` (granted automatically)
     - `Pull requests: Read-only`
   - Where can this GitHub App be installed: **Only on this account**.
2. On the App's **General** page: note the **App ID**, then under
   **Private keys** generate and download one (`.pem`). GitHub only
   shows it once, so regenerate it if lost.
3. **Install App** → **Install** on your account → **All
   repositories**, so a new repository's metrics need no change here.
   The installation page address is
   `https://github.com/settings/installations/<id>`, and that `<id>` is
   the **installation ID**.

## Store the credentials

`just bootstrap` prompts for the App ID, installation ID, and `.pem`
path, and stores them in Secret Manager. To store them without a full
bootstrap, or to roll out a new key, set the variables and run the
script. Supplied values overwrite the stored ones:

```sh
export GRAFANA_GITHUB_APP_ID=<app-id>
export GRAFANA_GITHUB_APP_INSTALLATION_ID=<installation-id>
export GRAFANA_GITHUB_APP_PRIVATE_KEY_FILE=<path-to-key.pem>

scripts/configure-grafana-github-secrets.sh
```

Shred the `.pem` once the script has stored it.

## Set the key on the data source

Set the key once `terraform/alunduil` has applied, after each key
rotation, and whenever the data source is recreated. Terraform leaves it
unset because the key would persist in bucket-readable state.

Prerequisites:

- `gcloud` and `jq` available, authenticated as an identity that can
  read the `grafana-github-app-private-key` secret.
- `gcx` logged in to the `alunduil` stack.

```sh
scripts/set-grafana-github-credentials.sh
```

Confirm it authenticates: **Connections → Data sources → `GitHub` →
Save & test**. Then in Explore, pick `GitHub`, choose the **Workflow
Runs** query type, and set owner `alunduil`, repository
`alunduil-infrastructure`, and workflow `terraform-apply.yml`. The
`Terraform Apply` runs appear.
