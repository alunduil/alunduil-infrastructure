<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Credentials

Token scopes, permissions, and conventions for every credential the
repo touches.

## Master Cloudflare token

Used once during `terraform/bootstrap/` apply to create the two
deployer Cloudflare tokens. Operator-only — never enters CI.

Required scopes:

- `User > API Tokens — Write`
- `Zone > Zone — Read`, `DNS — Read`, `Zone Settings — Read` on
  `alunduil.com`

Read on the zone is enough; the token only references it.

## Cloudflare API token (alunduil apply)

Used by day-to-day `terraform/alunduil/` apply when run locally.
Operator-supplied.

Required scopes on `alunduil.com`:

- `Zone:Read`
- `DNS:Edit`
- `Zone Settings:Edit`

Passed as `TF_VAR_cloudflare_api_token`, not `CLOUDFLARE_API_TOKEN`.
The v5 Cloudflare provider's import code path doesn't propagate the
env-var form, so the variable has to be set explicitly via the
`TF_VAR_` prefix to keep `import {}` blocks working.

## CI deployer Cloudflare tokens

Created by `terraform/bootstrap/` into the bootstrap state and
consumed by CI workflows. Two tokens, each scoped to `alunduil.com`:

- RO: `Zone Read`, `DNS Read`, `Zone Settings Read`
- RW: `Zone Read`, `DNS Write`, `Zone Settings Write`

## CI deployer GCP service accounts

Created by `terraform/bootstrap/` and impersonated via Workload
Identity Federation:

- `github-deployer-ro` — `terraform plan` runs
- `github-deployer-rw` — `terraform apply` on merge to `main`

Custom roles are scoped to `serviceusage` and
`resourcemanager.projects.get`; state-bucket access is granted
separately via bucket-level IAM. RW omits `billing.*` (billing lives
in bootstrap only).

## GitHub App

Used by the `integrations/github` Terraform provider in CI. The
workflow exchanges the App's ID + private key for short-lived
installation tokens via OIDC.

Required repository permissions:

- `Administration: Read and write`
- `Contents: Read and write`
- `Metadata: Read` (granted automatically)
- `Pages: Read and write`

Install scope: the entire account ("All repositories") so new repos
are picked up without re-issuing credentials.
