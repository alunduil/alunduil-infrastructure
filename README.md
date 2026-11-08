<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# alunduil-infrastructure

[![License](https://img.shields.io/github/license/alunduil/alunduil-infrastructure)](LICENSES/MIT.txt)
[![CI](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/ci.yml)
[![Terraform Apply](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/terraform-apply.yml/badge.svg?branch=main)](https://github.com/alunduil/alunduil-infrastructure/actions/workflows/terraform-apply.yml)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovatebot)](renovate.json)

Personal infrastructure as code, managed with Terraform.

**Repository:** <https://github.com/alunduil/alunduil-infrastructure>
**Author:** Alex Brandt \<<alunduil@gmail.com>\>

## Getting started

Changes reach the `alunduil` environment through CI. Opening a PR runs
`terraform plan` and posts the output as a PR comment. Merging to
`main` applies it automatically. Review the plan comment before
approving a merge.

Install the tools CI uses with `mise install`, or open the repository
in its devcontainer, which runs it for you. Then run `prek install`
to enable the commit hooks.

The three operator entrypoints:

- `just bootstrap`—first-time setup, and rotation of the credentials
  Terraform generates. See
  [docs/how-to/bootstrap.md](docs/how-to/bootstrap.md).
- `just alunduil`—break-glass local `terraform apply` on the
  alunduil environment, for when CI is unavailable.
- `just projects`—Projects v2 board fields, after editing a spec in
  `github/projects/`. Needs only a `gh` login with the `project` scope.

Ansible configures remote hosts from `ansible/`, run from the operator's
workstation:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook --inventory ansible/inventory.yml ansible/site.yml
```

If a run hangs while connecting, run `tailscale ssh nanopi-neo3 true` and
complete the browser login it asks for.

## Documentation

How-to guides for credentials:

- [Create the bootstrap Cloudflare token](docs/how-to/create-bootstrap-cloudflare-token.md)
- [Create the Terraform GitHub Apps](docs/how-to/create-terraform-github-apps.md)
- [Create the Git Sync GitHub App](docs/how-to/create-git-sync-github-app.md)
- [Rotate the Git Sync App's private key](docs/how-to/rotate-git-sync-app-key.md)
- [Create the Grafana Git Sync credentials](docs/how-to/create-grafana-git-sync-token.md)
- [Create the Grafana GitHub data source App](docs/how-to/create-grafana-github-app.md)
- [Create the hook-fix GitHub App](docs/how-to/create-hook-fix-github-app.md)
- [Create the GitHub Projects sync token](docs/how-to/create-github-project-sync-token.md)
- [Create the Tailscale trust credentials](docs/how-to/create-tailscale-trust-credential.md)
- [Create the blog's Web Analytics site](docs/how-to/create-web-analytics-site.md)

How-to guides for hosts and services:

- [Set the alloy push credential on the collector](docs/how-to/configure-alloy-push-credential.md)
- [Set the ACME token on TrueNAS](docs/how-to/configure-truenas-acme-token.md)
- [Connect Grafana Cloud to Google Cloud metrics and audit logs](docs/how-to/connect-grafana-to-gcp.md)
- [Configure the TrueNAS config backup](docs/how-to/configure-truenas-config-backup.md)
- [Configure the Google Takeout backup on TrueNAS](docs/how-to/configure-truenas-takeout-backup.md)

Reference:

- [Asset register](docs/reference/asset-register.md): estate assets, zones,
  principals, entry points, dependencies, and credentials
- [Delivery metrics](docs/reference/delivery-metrics.md): DORA and SPACE metric
  definitions against GitHub data

Explanation:

- [Credential reachability](docs/explanation/credential-reachability.md): why a
  leak of one credential can spread beyond what it was granted
- [Release path data flow](docs/explanation/release-path-data-flow.md): how a
  commit becomes a published package, and what crosses each trust boundary
- [Release path threat model](docs/explanation/threat-model-release-path.md):
  what can go wrong on that path, and where the release App fits

Decisions:

- [Architecture Decision Records](docs/adr/README.md)

## Support and contributions

This is personal infrastructure maintained for the author's own use.
Issues and pull requests from outside collaborators aren't actively
solicited and may not be triaged.

## License

MIT—see [LICENSES/MIT.txt](LICENSES/MIT.txt) or the
`SPDX-License-Identifier` headers on each file.
