<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the Inbox sync PAT

`INBOX_SYNC_TOKEN` authenticates the hourly Inbox sync workflow
(`.github/workflows/sync-inbox-project.yml`). It's a fine-grained
personal access token rather than a GitHub App so search can surface
private items in repos outside `alunduil/`, `dungeon-studio/`, and
`qua-world/` where the user is author or assignee.

## Mint

<https://github.com/settings/tokens?type=beta>

- **Resource owner**: `alunduil`
- **Repository access**: All repositories
- **Permissions**:
  - Projects (account): Read and write
  - Metadata (repository): Read
  - Issues (repository): Read
  - Pull requests (repository): Read
- **Expiration**: 1 year (fine-grained cap)

## Use

`scripts/configure-github-secrets.sh` pushes the token into the
`INBOX_SYNC_TOKEN` repo secret. Source the value, then run the script:

```sh
export INBOX_SYNC_TOKEN=...
scripts/configure-github-secrets.sh
```

If the secret is already populated, the script leaves it alone. Rotate
by exporting a fresh value and re-running.
