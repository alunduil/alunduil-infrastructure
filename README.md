<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# alunduil-infrastructure

[![License](https://img.shields.io/github/license/alunduil/alunduil-infrastructure)](LICENSES/MIT.txt)
[![pre-commit](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/pre-commit.yml/badge.svg?branch=main)](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/pre-commit.yml)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovatebot)](renovate.json)

Personal infrastructure as code, managed with Terraform.

**Repository:** <https://github.com/alunduil/alunduil-infrastructure>
**Author:** Alex Brandt \<<alunduil@gmail.com>\>

## Getting started

The two operator entrypoints:

- `just bootstrap` — first-time setup or credential rotation. See
  [docs/how-to/bootstrap.md](docs/how-to/bootstrap.md).
- `just alunduil` — local `terraform apply` against the alunduil
  environment, run after merging to `main`.

Supporting how-tos:

- [docs/how-to/create-master-cloudflare-token.md](docs/how-to/create-master-cloudflare-token.md)
- [docs/how-to/create-github-app.md](docs/how-to/create-github-app.md)
- [docs/how-to/create-grafana-git-sync-app.md](docs/how-to/create-grafana-git-sync-app.md)
- [docs/how-to/create-grafana-git-sync-token.md](docs/how-to/create-grafana-git-sync-token.md)
- [docs/how-to/create-web-analytics-site.md](docs/how-to/create-web-analytics-site.md)

## Support and contributions

This is personal infrastructure maintained for the author's own use.
Issues and pull requests from outside collaborators are not actively
solicited and may not be triaged.

## License

MIT — see [LICENSES/MIT.txt](LICENSES/MIT.txt) or the
`SPDX-License-Identifier` headers on each file.
