<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Connect the blog build to its Cloudflare analytics token

Run this once in `blog.alunduil.com` after the bootstrap apply. Bootstrap
already created the token, the Secret Manager entry, and the federation, so
only the workflow wiring is left. Rotation doesn't repeat it — the build
fetches the current value on every run.

## Prerequisites

- `just bootstrap` applied.
- Push access to `alunduil/blog.alunduil.com`.

## Collect the identifiers

None of these are credentials, so they belong in the workflow file rather
than in the repo's secrets:

```sh
terraform -chdir=terraform/bootstrap output -raw \
  blog_analytics_workload_identity_provider
terraform -chdir=terraform/bootstrap output -raw blog_analytics_reader_email
terraform -chdir=terraform/bootstrap output -raw \
  cloudflare_api_token_blog_analytics_ro_secret
```

## Wire up the Pages build

The federation is pinned to `.github/workflows/pages.yml` on `refs/heads/main`.
Adding these steps to another workflow, or moving them to another file, fails
the token exchange.

Grant the build job `id-token: write`, then exchange that token for the
secret and hand it to the Astro build:

```yaml
jobs:
  build:
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v7
      - uses: google-github-actions/auth@v3
        with:
          workload_identity_provider: PROVIDER_FROM_ABOVE
          service_account: EMAIL_FROM_ABOVE
      - id: analytics
        uses: google-github-actions/get-secretmanager-secrets@v2
        with:
          secrets: |-
            token:alunduil/SECRET_NAME_FROM_ABOVE
      - uses: withastro/action@v6
        env:
          CLOUDFLARE_ANALYTICS_API_TOKEN: ${{ steps.analytics.outputs.token }}
```

Pin each action by commit SHA, matching the rest of that repo's workflows.

## Confirm the Popular section renders

The build treats an absent or rejected token as "no data" and omits the
section, so a broken exchange still leaves a green run. Check the page, not
the exit status: after the next push to `main`, the homepage should carry a
Popular section between Featured and Recent.

When it doesn't, the logs name which half failed. `unable to acquire
impersonated credentials` from the `auth` step means the workflow's file path
or branch doesn't match the pinned `job_workflow_ref`. `authz: not authorized
for that account` in the build output means the token arrived but carries the
wrong scope.
