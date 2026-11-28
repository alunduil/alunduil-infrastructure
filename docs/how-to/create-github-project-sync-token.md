<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the GitHub Projects sync token

Generate and install the personal access token that the Projects
sync workflow reads from `GH_PROJECT_SYNC_TOKEN`. Follow this
both for first-time setup and for rotation.

## Generate the token

1. Open <https://github.com/settings/tokens> and select
   **Generate new token** → **Generate new token (classic)**. A
   fine-grained token can't write a user-owned Projects v2 board.
2. Fill in the form:
    - **Note**: `alunduil-infrastructure-project-sync`.
    - **Expiration**: **Custom**, a date one year out.
    - **Select scopes**: tick **`project`** only. Its `read:project`
      sub-scope ticks with it. Leave every other box clear.
3. Select **Generate token** and copy the value. GitHub shows it once.

`project` is all the sync needs: the board's items, fields, and owner
lookup, and reads of public issues and pull requests. Adding `repo` or
`public_repo` lets the token write to every repository the account
can. Without them, issues and pull requests in private repositories
stay off the board. If `dungeon-studio` or `qua-world` restricts
classic-token access in its org settings, approve this token there
too or its items won't sync.

## Install the token

Export the value and run the secrets script:

```sh
export GH_PROJECT_SYNC_TOKEN=<paste-here>
scripts/configure-github-secrets.sh
```

The script refuses a token whose scopes aren't exactly `project`,
before it writes any secret. Without the export, it keeps
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
