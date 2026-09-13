<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Connect the blog build to its Cloudflare analytics token

`terraform/bootstrap/` creates the analytics token, stores it in Secret
Manager, and federates one workflow in `blog.alunduil.com` into a service
account that can read it. Wiring the workflow up happens in that repo, so
run this once after the bootstrap apply. Rotation needs none of it again —
the build fetches the current value on every run.

## Prerequisites

- `just bootstrap` applied.
- Push access to `alunduil/blog.alunduil.com`.

## Collect the three identifiers

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

The federation is pinned to `.github/workflows/pages.yml` on `refs/heads/main`
and to the `blog` identity pool. Adding these steps to another workflow, or
moving them to another file, fails the token exchange.

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

## Confirm it worked

The build treats an absent or rejected token as "no data" and omits the
Popular section, so a broken exchange leaves a green run. Check the widget
rather than the exit status: after the next push to `main`, confirm the
homepage renders a Popular section between Featured and Recent.

If it doesn't, the `auth` step's log names the failure. `unable to
acquire impersonated credentials` means the workflow, its file path, or its
branch doesn't match the pinned `job_workflow_ref`; a Cloudflare
`authz: not authorized for that account` in the build log means the token
reached the build but carries the wrong scope.
