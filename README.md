<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# alunduil-infrastructure

[![License](https://img.shields.io/github/license/alunduil/alunduil-infrastructure)](LICENSES/MIT.txt)
[![pre-commit](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/pre-commit.yml/badge.svg?branch=main)](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/pre-commit.yml)
[![Terraform Apply](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/terraform-apply.yml/badge.svg?branch=main)](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/terraform-apply.yml)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovatebot)](renovate.json)

Personal infrastructure as code, managed with Terraform.

**Repository:** <https://github.com/alunduil/alunduil-infrastructure>
**Author:** Alex Brandt \<<alunduil@gmail.com>\>

## Getting started

Changes reach the `alunduil` environment through CI. Opening a PR runs
`terraform plan` and posts the output as a PR comment; merging to
`main` applies it automatically. Review the plan comment before
approving a merge.

The two operator entrypoints:

- `just bootstrap` — first-time setup or credential rotation. See
  [docs/how-to/bootstrap.md](docs/how-to/bootstrap.md).
- `just alunduil` — break-glass local `terraform apply` against the
  alunduil environment, for when CI is unavailable.

Supporting how-tos:

- [docs/how-to/create-master-cloudflare-token.md](docs/how-to/create-master-cloudflare-token.md)
- [docs/how-to/create-deployer-github-app.md](docs/how-to/create-deployer-github-app.md)
- [docs/how-to/create-git-sync-github-app.md](docs/how-to/create-git-sync-github-app.md)
- [docs/how-to/create-grafana-git-sync-token.md](docs/how-to/create-grafana-git-sync-token.md)
- [docs/how-to/create-web-analytics-site.md](docs/how-to/create-web-analytics-site.md)

## Support and contributions

This is personal infrastructure maintained for the author's own use.
Issues and pull requests from outside collaborators are not actively
solicited and may not be triaged.

## License

MIT — see [LICENSES/MIT.txt](LICENSES/MIT.txt) or the
`SPDX-License-Identifier` headers on each file.
