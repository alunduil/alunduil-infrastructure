<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the deployer GitHub Apps

Two GitHub Apps authenticate the `integrations/github` Terraform provider
in CI. Plan runs whatever workflow a pull request supplies, so it uses a
read-only App. Apply uses a read-write App whose key only
`terraform-apply.yml` on `main` can read.

## Create the Apps

Create each App at <https://github.com/settings/apps/new> with:

- **GitHub App name**: `alunduil-terraform-plan` or
  `alunduil-terraform-apply`. GitHub credits each change the App makes to
  this name. Renaming one means renaming it in
  `scripts/configure-deployer-github-secrets.sh` too.
- **Description**:
  - Plan: `Read-only access for terraform plan in
    alunduil/alunduil-infrastructure. Only the plan deployer service
    account can read its key.`
  - Apply: `Write access for terraform apply in
    alunduil/alunduil-infrastructure, from main only.`
- **`Homepage URL`** (required): the repo,
  `https://github.com/alunduil/alunduil-infrastructure`.
- **Webhook**: uncheck **Active**.
- Leave the user-authorization checkboxes under `Callback URL` at their
  defaults. Both Apps authenticate as an installation, not a user.
- Where can this GitHub App be installed: **Only on this account**. A
  leaked key reaches every account that installs the App.
- Repository permissions (everything else **No access**):

  | Permission | `alunduil-terraform-plan` | `alunduil-terraform-apply` |
  | --- | --- | --- |
  | `Administration` | Read-only | Read and write |
  | `Contents` | Read-only | Read and write |
  | `Metadata` | Read-only | Read-only |
  | `Pages` | Read-only | Read and write |

Then, for each App:

1. On the App's **General** page, note the **App ID**, then under
   **Private keys** generate and download one (`.pem`). GitHub only
   shows it once, so regenerate it if lost.
2. **Install App** → **Install** on your account → **All repositories**,
   so a new repository works without new credentials.

## Store the credentials

`just bootstrap` prompts for each App's ID and `.pem` path and stores
them in Secret Manager. To store them without a full bootstrap, or to
roll out a new key, set the variables and run the script. Supplied
values overwrite the stored ones:

```sh
export DEPLOYER_GITHUB_APP_ID_RO=<read-only-app-id>
export DEPLOYER_GITHUB_APP_PRIVATE_KEY_FILE_RO=<path-to-read-only-key.pem>
export DEPLOYER_GITHUB_APP_ID_RW=<read-write-app-id>
export DEPLOYER_GITHUB_APP_PRIVATE_KEY_FILE_RW=<path-to-read-write-key.pem>

scripts/configure-deployer-github-secrets.sh
```

Shred each `.pem` once the script has stored it.
