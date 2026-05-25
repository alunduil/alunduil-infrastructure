<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Manual operations

A few things sit outside Terraform — either the provider doesn't expose
them cleanly, or they're one-time bootstraps. Set them up before (or
alongside) an apply.

## `develop` → `main` renames

Terraform can't safely rename an existing default branch. Use GitHub's
repository "Rename branch" feature so PR refs and forks are preserved,
then let `github_branch_default` lock `main` in.

## HTTPS enforcement on Pages

GitHub provisions the certificate on its own once the CNAME resolves;
tick "Enforce HTTPS" in Pages settings after the cert is ready.

## Cloudflare API token

`terraform plan`/`apply` from `terraform/alunduil/` needs
`TF_VAR_cloudflare_api_token` exported in the shell, scoped to
`Zone:Read`, `DNS:Edit`, and `Zone Settings:Edit` on `alunduil.com`.
Mint at <https://dash.cloudflare.com/profile/api-tokens>. The
`TF_VAR_` form rather than `CLOUDFLARE_API_TOKEN` is a workaround
for an upstream bug in the v5 provider's import code path.

## GCP DNS zone deletion

The legacy `alunduil-com` Cloud DNS zone is no longer Terraform-managed.
After the apply removes the `google_dns_*` resources, delete the empty
zone in the GCP console (or `gcloud dns managed-zones delete
alunduil-com`) to release it.
