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

Day-to-day apply runs from `terraform/alunduil/`; first-time setup runs
from `terraform/bootstrap/`. Detailed runbooks:

- [docs/how-to/apply.md](docs/how-to/apply.md) — day-to-day apply
- [docs/how-to/bootstrap.md](docs/how-to/bootstrap.md) — first-time
  bootstrap, master Cloudflare token, GitHub App setup
- [docs/reference/manual-operations.md](docs/reference/manual-operations.md)
  — things that stay outside Terraform

## Support and contributions

This is personal infrastructure maintained for the author's own use.
Issues and pull requests from outside collaborators are not actively
solicited and may not be triaged.

## Licence

MIT — see [LICENSES/MIT.txt](LICENSES/MIT.txt) or the
`SPDX-License-Identifier` headers on each file.
