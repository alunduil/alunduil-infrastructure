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
- **DNS** — `alunduil.com` zone and all records (`blog`, `home`, `groton`, …)
- **GitHub repositories** — settings (visibility, merge rules, discussions, …),
  default branch, branch protection, and (opt-in) Pages for repositories
  owned by `alunduil`, applied via classification (`default`,
  `release-please`)

All Terraform lives in [`terraform/alunduil/`](terraform/alunduil/). There is
one environment (this is personal homelab infrastructure, equivalent in scope
to a single production project).

### Stays manual

A few repo-side knobs aren't covered by Terraform and have to be set in the
GitHub UI before (or alongside) an apply:

- **`develop` → `main` rename.** Terraform can't safely rename an existing
  branch. Use GitHub's repository "Rename branch" feature so PR refs and
  forks are preserved, then let `github_branch_default` lock `main` in.
- **HTTPS enforcement on Pages.** GitHub provisions the certificate on its
  own once the CNAME resolves; tick "Enforce HTTPS" in Pages settings after
  the cert is ready. (The provider doesn't expose this cleanly enough yet.)

## Support and contributions

This is personal infrastructure maintained for the author's own use. Issues
and pull requests from outside collaborators are not actively solicited and
may not be triaged.

## Licence

MIT — see [LICENSES/MIT.txt](LICENSES/MIT.txt) or the `SPDX-License-Identifier`
headers on each file.
