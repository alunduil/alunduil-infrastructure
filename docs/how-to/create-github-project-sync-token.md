<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the GitHub Projects sync token

Generate and install the personal access token that the Projects
sync workflow reads from `GH_PROJECT_SYNC_TOKEN`. Follow this
both for first-time setup and for rotation.

## Generate the token

1. Open <https://github.com/settings/tokens> and select
   **Generate new token (classic)**. A fine-grained token can't write
   a user-owned Projects v2 board.
2. **Note**: any (for example, `alunduil-infrastructure-project-sync`).
3. **Expiration**: 1 year.
4. Select scopes:
    - **`project`**—add and update board items.
    - **`read:org`**—resolve the org-owned sources. `gh project`
      also needs it to look up the board's owner, even a user one.
5. Select **Generate token** and copy the value.

Keep the scope set to `project` + `read:org` on rotation. Adding
`repo` or `public_repo` lets the token write to every repository the
account can. Without them, the sync reads public repositories only,
so issues and pull requests in private repositories stay off the
board. If `dungeon-studio` or `qua-world` restricts classic-token
access in its org settings, approve this token there too or its items
won't sync.

## Install the token

Export the value and run the secrets script:

```sh
export GH_PROJECT_SYNC_TOKEN=<paste-here>
scripts/configure-github-secrets.sh
```

The script refuses a token whose scopes aren't exactly `project` and
`read:org`, before it writes any secret. Without the export, it keeps
the secret already set. It upserts the secret, so re-running with the
same value is a no-op. It stores the token on the `project-sync` deployment
environment (restricted to `main`), not as a repo secret, so only the
sync workflow—which declares that environment—can read it. The
other CI secrets stay repo-level.

## Rotate

1. Repeat **Generate the token**.
2. Re-run **Install the token** with the new value.
3. Dispatch the Hourly workflow and confirm the sync job succeeds:

    ```sh
    gh workflow run hourly.yml
    ```

4. Delete the old token at <https://github.com/settings/tokens>.
