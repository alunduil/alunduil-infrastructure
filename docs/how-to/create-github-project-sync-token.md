<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the GitHub Projects sync PAT

Mint and install the personal access token that the Projects sync
workflow reads from `GITHUB_PROJECT_SYNC_TOKEN`. Follow this both
for first-time setup and for rotation.

## Mint the token

1. Open <https://github.com/settings/tokens?type=beta>.
2. Click **Generate new token**.
3. Fill in:
    - **Token name**: any (e.g. `alunduil-infrastructure-project-sync`).
    - **Resource owner**: `alunduil`.
    - **Expiration**: 1 year (the fine-grained cap).
    - **Repository access**: **All repositories**.
4. Under **Account permissions**, grant **Projects: Read and write**.
5. Under **Repository permissions**, grant:
    - **Metadata: Read**
    - **Issues: Read**
    - **Pull requests: Read**
6. Click **Generate token** and copy the value.

## Install the token

Export the value and run the secrets script:

```sh
export GITHUB_PROJECT_SYNC_TOKEN=<paste-here>
scripts/configure-github-secrets.sh
```

The script upserts the secret; re-running with the same value is a
no-op.

## Rotate

Repeat **Mint the token**, then re-run **Install the token** with the
new value. The next workflow run picks it up.
