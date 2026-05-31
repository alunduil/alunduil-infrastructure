<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the GitHub Projects sync PAT

Generate and install the personal access token that the Projects
sync workflow reads from `GITHUB_PROJECT_SYNC_TOKEN`. Follow this
both for first-time setup and for rotation.

## Generate the token

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

Every grant is read-only except **Projects: Read and write**, which
the sync needs to add and update board items. **All repositories** is
required because the board mirrors issues and pull requests you're
assigned to across repos the token can't enumerate ahead of time;
narrowing the repository access would silently drop those items. Keep
this set on rotation — don't add **Contents** or other write scopes
the sync doesn't use.

## Install the token

Export the value and run the secrets script:

```sh
export GITHUB_PROJECT_SYNC_TOKEN=<paste-here>
scripts/configure-github-secrets.sh
```

The script upserts the secret; re-running with the same value is a
no-op. It stores the token on the `project-sync` deployment
environment (restricted to `main`), not as a repo secret, so only the
sync workflow — which declares that environment — can read it. The
other CI secrets stay repo-level.

## Rotate

Repeat **Generate the token**, then re-run **Install the token**
with the new value. The next workflow run picks it up.
