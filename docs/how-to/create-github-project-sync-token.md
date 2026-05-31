<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the GitHub Projects sync PAT

Generate and install the personal access token that the Projects
sync workflow reads from `GITHUB_PROJECT_SYNC_TOKEN`. Follow this
both for first-time setup and for rotation.

## Generate the token

1. Open <https://github.com/settings/tokens> and click
   **Generate new token (classic)**. A fine-grained token can't write
   a user-owned Projects v2 board.
2. **Note**: any (e.g. `alunduil-infrastructure-project-sync`).
3. **Expiration**: 1 year.
4. Select scopes:
    - **`project`** — add and update board items.
    - **`repo`** — read issues and pull requests across the board's
      sources, private repos included.
5. Click **Generate token** and copy the value.

Keep the scope set to `project` + `repo` on rotation. If
`dungeon-studio` or `qua-world` restricts classic-token access in its
org settings, approve this token there too or its items won't sync.

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
