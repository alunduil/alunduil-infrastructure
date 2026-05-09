<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# alunduil-infrastructure

[![License](https://img.shields.io/github/license/alunduil/alunduil-infrastructure)](LICENSES/MIT.txt)

Personal infrastructure as code, managed with Terraform. `terraform plan`
and `apply` are run manually after merge to `main`.

**Repository:** <https://github.com/alunduil/alunduil-infrastructure>
**Author:** Alex Brandt \<<alunduil@gmail.com>\>

## What this manages

- **GCP project** — the `alunduil` project itself (billing, labels,
  foundational APIs)
- **DNS** — records under `alunduil.com` (the zone is hosted on Cloudflare;
  Terraform manages records, not the zone itself)
- **GitHub repositories** — settings (visibility, merge rules, discussions, …),
  default branch, branch protection, and (opt-in) Pages for repositories
  owned by `alunduil`, applied via classification (`default`,
  `release-please`)

All Terraform lives in [`terraform/alunduil/`](terraform/alunduil/). There is
one environment (this is personal homelab infrastructure, equivalent in scope
to a single production project).

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
