<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# alunduil-infrastructure

[![License](https://img.shields.io/github/license/alunduil/alunduil-infrastructure)](LICENSES/MIT.txt)
[![pre-commit](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/pre-commit.yml/badge.svg?branch=main)](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/pre-commit.yml)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovatebot)](renovate.json)

Personal infrastructure as code, managed with Terraform.

**Repository:** <https://github.com/alunduil/alunduil-infrastructure>
**Author:** Alex Brandt \<<alunduil@gmail.com>\>

## What this manages

- **GCP project** — the `alunduil` project itself (billing, labels,
  foundational APIs)
- **DNS** — the `alunduil.com` Cloudflare zone, a security-relevant subset of
  zone settings (`ssl`, `min_tls_version`, `always_use_https`,
  `automatic_https_rewrites`), and all records under it. Other zone settings
  track Cloudflare's defaults.
- **GitHub repositories** — settings (visibility, merge rules, discussions, …),
  default branch, branch protection, and (opt-in) Pages for repositories
  owned by `alunduil`, applied via classification (`default`,
  `release-please`)

Terraform is split across two configs in [`terraform/`](terraform/):

- [`terraform/alunduil/`](terraform/alunduil/) — day-to-day infrastructure
  (Cloudflare zone, GitHub repos, project-level services). Applied on merge
  to `main`.
- [`terraform/bootstrap/`](terraform/bootstrap/) — the GCP project itself,
  the foundational APIs (`iam`, `cloudresourcemanager`, `serviceusage`), the
  GitHub Workload Identity Federation pool/provider, and the two scoped
  deployer service accounts that the CI workflows impersonate. Applied
  rarely, locally; keeps billing perms out of the main config (and out of
  CI).

There is one environment (this is personal homelab infrastructure,
equivalent in scope to a single production project).

## Running an apply

`terraform plan`/`apply` are run manually after merge to `main`. The
shell environment (Terraform, gcloud, pre-commit, REUSE) is prepared by
chezmoi outside this repo.

From `terraform/alunduil/`:

```sh
gcloud auth application-default login    # GCP creds (google provider + gcs backend)
export TF_VAR_cloudflare_api_token=...   # see "Stays manual" below
export GITHUB_TOKEN=...                  # scopes for repository administration

terraform init
terraform plan
terraform apply
```

## First-time bootstrap

Only run when standing up CI authentication from scratch, or when rotating
the WIF pool / deployer service accounts. The state bucket itself
(`alunduil-tfstate`) is created out-of-band by
[`scripts/bootstrap-terraform-state.sh`](scripts/bootstrap-terraform-state.sh).

From `terraform/bootstrap/`:

```sh
gcloud auth application-default login
export TF_VAR_billing_account_id=XXXXXX-XXXXXX-XXXXXX
export CLOUDFLARE_API_TOKEN=...   # master, see "Master Cloudflare token" below

terraform init
terraform plan
terraform apply
```

The first apply imports the existing project and three foundational APIs
into bootstrap state, then mints two scoped Cloudflare API tokens for the
CI deployers. After it succeeds, run a one-off apply in
`terraform/alunduil/` so its `removed{}` blocks forget the same four
resources from main state (without destroying them).

Then populate the eight GitHub Actions secrets:

```sh
export GH_APP_PRIVATE_KEY="$(cat /path/to/your-app.pem)"
scripts/configure-github-secrets.sh
```

The script reads six values from `terraform output` (four GCP — WIF
provider + RO/RW service-account emails — and two Cloudflare deployer
token values). For the two GitHub App secrets (`GH_APP_ID`,
`GH_APP_PRIVATE_KEY`), it prefers an env-var value, falls back to the
existing repo secret if one is set, and prompts (or in the case of the
PEM, exits with instructions) only when both are missing. Re-running is
a no-op.

### Master Cloudflare token

Bootstrap apply needs a token with the scopes to (a) read permission
groups, (b) create user-owned tokens, and (c) be authorized for
`alunduil.com`:

- `User > API Tokens — Write`
- `Zone > Zone — Read`, `DNS — Read`, `Zone Settings — Read` on
  `alunduil.com` (read is enough; the token only references the zone)

This token is operator-only — it never lives in CI. Mint at
<https://dash.cloudflare.com/profile/api-tokens> for the bootstrap apply,
revoke afterwards if you don't keep it around for rotation.

### GitHub App

The terraform `integrations/github` provider authenticates via a GitHub
App that the workflow exchanges for short-lived installation tokens.
One-time setup:

1. Create at <https://github.com/settings/apps/new>:
   - Webhook: uncheck "Active"
   - Repository permissions: Administration RW, Contents RW, Metadata R
     (auto), Pages RW
2. Install on your account, select "All repositories" so new repos are
   auto-covered.
3. Note the App ID, generate and download a private key (.pem).
4. Export `GH_APP_ID` and `GH_APP_PRIVATE_KEY` (the latter from the .pem
   contents) before running `scripts/configure-github-secrets.sh`.

### Stays manual

A few things sit outside Terraform — either the provider doesn't expose
them cleanly, or they're one-time bootstraps. Set them up before (or
alongside) an apply:

- **`develop` → `main` renames.** Terraform can't safely rename an
  existing default branch. Use GitHub's repository "Rename branch"
  feature so PR refs and forks are preserved, then let
  `github_branch_default` lock `main` in.
- **HTTPS enforcement on Pages.** GitHub provisions the certificate on
  its own once the CNAME resolves; tick "Enforce HTTPS" in Pages
  settings after the cert is ready.
- **Cloudflare API token.** `terraform plan`/`apply` needs
  `TF_VAR_cloudflare_api_token` exported in the shell, scoped to
  `Zone:Read`, `DNS:Edit`, and `Zone Settings:Edit` on `alunduil.com`.
  Mint at <https://dash.cloudflare.com/profile/api-tokens>. (The
  `TF_VAR_` form rather than `CLOUDFLARE_API_TOKEN` is a workaround
  for an upstream bug in the v5 provider's import code path.)
- **GCP DNS zone deletion.** The legacy `alunduil-com` Cloud DNS zone
  is no longer Terraform-managed. After the apply removes the
  `google_dns_*` resources, delete the empty zone in the GCP console
  (or `gcloud dns managed-zones delete alunduil-com`) to release it.

## Support and contributions

This is personal infrastructure maintained for the author's own use. Issues
and pull requests from outside collaborators are not actively solicited and
may not be triaged.

## Licence

MIT — see [LICENSES/MIT.txt](LICENSES/MIT.txt) or the `SPDX-License-Identifier`
headers on each file.
