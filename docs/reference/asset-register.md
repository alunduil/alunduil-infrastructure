<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Asset register

Lists the personal estate for threat modeling: zones, principals,
trust boundaries, assets, entry points, external dependencies, and
credentials. [Credential reachability](../explanation/credential-reachability.md)
follows what each credential leads to.

Verified 2026-11-07.

## Scope

Follows the enumeration [OWASP's threat modeling
process](https://community.owasp.org/Threat_Modeling_Process) asks for.

Out of scope:

- Component inventory fields—model, serial number, firmware version,
  exact location, and per-device addresses. Those live in a private
  Notion inventory.
- Criticality tiers and data classification, which belong to a
  reliability map rather than a threat model.
- The workstation's own configuration, which belongs to
  `alunduil/alunduil-chezmoi`.
- Secret values and their storage paths.
- Hardware identifiers such as Media Access Control (MAC) addresses,
  which public wireless-survey databases can tie to a street address.

An `Unverified` field was out of reach of both the repository and a
live query at the verification date.

## Zones

Network positions, ordered by trust. An asset's exposure is the
least-trusted zone with a path to it, and no asset has more than one.

| ID | Name | Who is in it |
| --- | --- | --- |
| T-1 | Public internet | Anyone |
| T-2 | Home network | `192.168.68.0/22`, ~20 devices, 11 unidentified |
| T-3 | Tailnet | Devices approved onto the tailnet |

A-04 translates addresses between T-1 and T-2, so T-1 reaches a T-2
asset either through a forward or through a vendor cloud the asset dials
out to. One forward exists, for E-01. E-03 and E-08 are cloud paths.
E-05's Server Message Block (SMB), E-06, E-11 and E-12 answer nothing on
the Wide Area Network (WAN) address and have no cloud path.

## Principals

Identities that hold credentials, as distinct from the zones they act
from.

| ID | Name | Identity | Invoked from |
| --- | --- | --- | --- |
| P-1 | Operator | A console, or a shell on A-06 | Whoever holds either |
| P-2 | CI plan | `terraform plan` in Actions | T-1, by pull request |
| P-3 | CI apply | `terraform apply` in Actions | A push to `main` |
| P-4 | Host service | A service with its own credential | The host's holder |
| P-5 | Hook fix | C-25's App token in Actions | A Renovate pull request |
| P-6 | Renovate | Mend's App, ID 2740, on every repository | Mend |
| P-7 | Write collaborator | A person with write access | Their account |
| P-8 | Claude | Anthropic's App, ID 1236702, on every repository | Anthropic |
| P-9 | Codecov | Codecov's App, ID 254, on every repository | Codecov |
| P-10 | Release workflow | A job in `release.yml` | E-13, E-14, E-15, a merge |
| P-11 | `GITHUB_TOKEN` | Actions' token for one job | Any workflow run |
| P-12 | Release App | Planned in #556, not created | P-10 |

The vendor Apps hold these permissions:

- P-6: `contents`, `workflows`, and `checks` write
- P-8: `contents`, `workflows`, `actions`, and `repository_hooks` write
- P-9: reads contents, and reports checks and statuses

P-11 reads by default, and a job's `permissions:` block can widen that. Tags
and Releases it creates start no workflow, but a dispatch it sends does. Every
managed repository refuses it pull request creation.

## Trust boundaries

Privilege changes that aren't a zone edge. The boundaries between zones
are implied by their order. These sit inside a single host.

| ID | Boundary | Separates |
| --- | --- | --- |
| B-1 | Container isolation on A-01 | A-12 and five other apps from A-01 |
| B-2 | Add-on isolation on A-02 | Eight add-ons from A-02 |

B-1 differs per container.

| Container | Isolation | Reaches |
| --- | --- | --- |
| A-12 | No host mounts, media read-only, non-root | Its datasets |
| Netdata | `/proc`, `/sys`, Docker socket, root | A-01 |
| Scrutiny | `/dev`, `/run/udev`, `MKNOD`, root | A-01's disks |
| alloy, Tailscale, `ddns-updater` | Unchecked | `Unverified` |

The TrueNAS catalogue entries for these containers run as root. A-12's
configuration overrides that with a named user.

The unchecked containers each keep a credential in their application
configuration, which is what reading them would expose.

B-2 is unchecked.

## Assets

Hosts and devices alunduil owns, and accounts this repository
configures. P-1 administers every asset. `Terraform access` names the
principals that read or change an asset through Terraform.

### A-01: `truenas`

- Description: network storage and application host. Runs
  Plex, Netdata, alloy, Tailscale, `ddns-updater`, and Scrutiny.
  Advertises `192.168.68.0/22` to the tailnet as a subnet router, and
  offers an exit node
- Exposed to: T-2, via E-05. A-12 carries its only path from T-1

### A-02: `homeassistant`

- Description: home automation hub. Runs Zigbee2MQTT, Mosquitto, a
  Matter server, an OpenThread Border Router, alloy, Tailscale, SSH,
  and the File editor. Every automation in the house runs here
- Exposed to: T-1, via E-03

### A-03: `slzb-mr4u`

- Description: Zigbee and Thread radio coordinator, carrying every
  Zigbee message the house sends. A-02's Zigbee2MQTT depends on it.
  A-02 reaches the Thread radio the same way, but no Thread devices
  are paired, so that half is unexercised
- Exposed to: T-2, via E-07

### A-04: Deco mesh

- Description: router, Wi-Fi mesh, Domain Name System (DNS) relay, and
  Dynamic Host Configuration Protocol (DHCP). Three units. Owns the DHCP
  reservations that T-2 hostnames follow, and the app that holds them is
  the only place they exist. Translates addresses between T-1 and T-2
- Exposed to: T-1, via E-08. Its management interface also answers 80
  and 443 on the WAN address from inside the network. Whether it
  answers from outside is `Unverified`

### A-05: `nanopi-neo3`

- Description: Tailscale exit node presenting a US address. Sits in
  the American Midwest in a household that isn't alunduil's, and is
  administered remotely from London. Runs alloy, enrolled in Fleet
  Management as collector `NanoPi-NEO3`. Recovery is
  [ADR 0002](../adr/0002-build-nanopi-neo3-recovery-image-with-armbian.md)
- Exposed to: T-3, via E-09

### A-06: `penguin`

- Description: operator workstation, a Crostini container. Runs
  break-glass Terraform applies, `chezmoi`, and Claude Code, so it
  holds the operator's credentials
- Exposed to: no inbound path, since it initiates its own connections

### A-07: Google Cloud

- Description: project `alunduil` in `europe-west1`, holding the
  Terraform state bucket, Secret Manager, the workload identity federation
  pools, and the audit log configuration
- Exposed to: T-1. Its API is public
- Terraform access: P-2, P-3

### A-08: Cloudflare

- Description: zone `alunduil.com`, DNSSEC active. Authoritative DNS
  and zone settings. Every record except `home.alunduil.com` is
  declared in `terraform/alunduil/dns.tf`. That one is written by
  `ddns-updater` on A-01
- Exposed to: T-1, both as a resolver and through a public API
- Terraform access: P-2, P-3

### A-09: GitHub

- Description: account `alunduil`, source of record for every managed
  repository, and the runtime that applies this infrastructure. Repository
  settings are declared in `terraform/alunduil/repositories.tf`
- Exposed to: T-1, via E-02 and E-04
- Terraform access: P-2, P-3

### A-10: Tailscale

- Description: tailnet `tail3af06.ts.net`, joining every host listed
  earlier. Device approval on, key duration 180 days, MagicDNS on, HTTPS
  certificates on, global nameservers pinned to Quad9. Both exit nodes
  carry per-device key-expiry exemptions set outside Terraform. The policy
  file is declared in `terraform/alunduil/tailscale-acl.hujson`
- Exposed to: T-1. Its API is public. It provides T-3
- Terraform access: P-2, P-3

### A-11: Grafana Cloud

- Description: stack `alunduil` in `prod-gb-south-1`. Metrics, logs,
  traces, profiles, and dashboards, syncing from this repository's
  `grafana/` directory through Git Sync. Alerts page P-1 through IRM,
  declared in `terraform/alunduil/alerting.tf`
- Exposed to: T-1. Its API is public
- Terraform access: P-2, P-3

### A-12: Plex

- Description: media server, running as a container on A-01 and reading
  the library from its pool read-only
- Exposed to: T-1, via E-01

## Entry points

Interfaces where data arrives. Each names the asset a client
reaches: the container where B-1 holds, and the host where it doesn't,
which is why E-01 names A-12 and E-11 names A-01.

| ID | Interface | Asset | Reachable from |
| --- | --- | --- | --- |
| E-01 | Plex on 32400 at `plex.alunduil.com` | A-12 | T-1 |
| E-02 | `blog.alunduil.com`, served by GitHub Pages | A-09 | T-1 |
| E-03 | The Nabu Casa remote interface | A-02 | T-1 |
| E-04 | Pull requests to a public repository | A-09 | T-1 |
| E-05 | Web interface on 443, SMB on 445, HTTP on 80 | A-01 | T-2 |
| E-06 | Home Assistant on 8123 | A-02 | T-2 |
| E-07 | Web interface on 80, `_slzb-06._tcp` on 7638 | A-03 | T-2 |
| E-08 | Administration through the Deco app, via D-06 | A-04 | T-1 |
| E-09 | Services published to the tailnet | A-01, A-02, A-05 | T-3 |
| E-11 | Netdata on 20489 | A-01 | T-2 |
| E-12 | Scrutiny on 31054 and 31055 | A-01 | T-2 |
| E-13 | Tag creation, through Git or the API | A-09 | T-1 |
| E-14 | Release creation, through the API | A-09 | T-1 |
| E-15 | `workflow_dispatch` on a release workflow | A-09 | T-1 |

E-13 and E-14 need `Contents` write, and E-15 needs `Actions` write. Each can
start a publish. The
[release path threat model](../explanation/threat-model-release-path.md) walks
all three.

Plex asks a T-1 client to sign in. Its allowed-networks setting covers
every private IPv4 range, so a client already in T-2 reaches it without
signing in.

E-04 reaches P-2's credentials, because `terraform-plan.yml` triggers on
`pull_request` with no environment gate. A fork's token matches nothing,
because the pool in `terraform/bootstrap/github_oidc.tf` requires this
repository.

## External dependencies

Third parties the estate relies on, and what leaves to each. A-07
through A-11 appear here and in Assets: the asset entry records
what the estate holds there, and this one records what reaches the
vendor.

| ID | Service | What leaves |
| --- | --- | --- |
| D-01 | Nabu Casa | A-02's backups, and its remote interface traffic |
| D-02 | Google Drive | A-01's backups, Takeout archives, A-05's `/home` |
| D-03 | Quad9 | Every DNS query from A-10, and from T-2 via A-04 |
| D-04 | UptimeRobot | Probes of E-01, heartbeats from A-02 and A-05 |
| D-05 | Squarespace | Registrar for `alunduil.com`, holding its DS records |
| D-06 | TP-Link cloud | Administration of A-04, telemetry (`Unverified`) |
| D-07 | Google Cloud (A-07) | Terraform state and every secret |
| D-08 | Cloudflare (A-08) | Zone configuration, the home address via C-15 |
| D-09 | GitHub (A-09) | Repositories, CI logs, and Release assets |
| D-10 | Tailscale (A-10) | Node keys and tailnet membership |
| D-11 | Grafana Cloud (A-11) | Telemetry from A-01, A-02, A-03, A-06 |
| D-12 | Hackage | Haskell packages, which can't be recalled |
| D-13 | PyPI | `zfs-replicate` distributions |

`woodland-generators` ships through D-09's Release assets, which Foundry
installs from.

## Credentials

The credentials this repository declares or documents, in ID order. Fields
with a specific meaning:

- `Grants`: the principal holding the credential or, where no listed
  principal holds it, what it allows.
- `Created by`: `Terraform` means `terraform apply` creates and rotates it.
  `Operator` means someone creates it in a console, and no apply rotates it.
- `Source`: the Terraform file that declares it or the how-to that creates
  it. `None` means nothing here does either.
- `Tracked by`: the issue that changes it, where one exists.

A credential in a provider console with no entry below is an
orphan. Two inventories are complete at the verification date:
Grafana Cloud's, which held C-18, and Google Cloud's OAuth clients, which
held C-23. Nobody has enumerated Cloudflare, GitHub, Tailscale, or
Google Cloud's other credentials.

### C-01: `alunduil-infrastructure deployer (RO)`

- Kind: Cloudflare API token
- Scope: Zone Read, DNS Read, and Zone Settings Read on `alunduil.com`
- Consumer: `terraform plan` in CI
- Grants: P-2
- Created by: Terraform
- Source: `terraform/bootstrap/cloudflare_tokens.tf`

### C-02: `alunduil-infrastructure deployer (RW)`

- Kind: Cloudflare API token
- Scope: Zone Read, DNS Write, and Zone Settings Write on
  `alunduil.com`
- Consumer: `terraform apply` in CI, and `just alunduil`
- Grants: P-3, and P-1 through the break-glass path
- Created by: Terraform
- Source: `terraform/bootstrap/cloudflare_tokens.tf`

### C-03: `github-deployer-ro`

- Kind: Google Cloud service account
- Scope: the `githubDeployerPlanner` custom role, and object read on
  the state bucket
- Consumer: `terraform plan` in CI, through workload identity
  federation
- Grants: P-2
- Created by: Terraform
- Source: `terraform/bootstrap/service_account_github_deployer_ro.tf`

### C-04: `github-deployer-rw`

- Kind: Google Cloud service account
- Scope: the `githubDeployerApplier` custom role, and object admin on
  the state bucket
- Consumer: `terraform apply` in CI, restricted to
  `.github/workflows/terraform-apply.yml` on `refs/heads/main`
- Grants: P-3
- Created by: Terraform
- Source: `terraform/bootstrap/service_account_github_deployer_rw.tf`

### C-05: `grafana-gcp-reader`

- Kind: Google Cloud service account key
- Scope: `monitoring.viewer`, `logging.viewer`, `logging.viewAccessor`
- Consumer: A-11's Cloud Monitoring and Cloud Logging data sources
- Grants: Google Cloud metrics and logs, to whoever queries A-11
- Created by: Terraform
- Source: `terraform/bootstrap/grafana_gcp_reader.tf`

### C-06: `alunduil-infrastructure-provisioner`

- Kind: Grafana stack service account token
- Scope: stack Admin
- Consumer: the Grafana resources in `terraform/alunduil/`, in both plan
  and apply
- Grants: P-2, P-3
- Created by: Terraform
- Source: `terraform/bootstrap/grafana.tf`

### C-07: Bootstrap Cloudflare token

- Kind: Cloudflare API token, time-limited
- Scope: `User:API Tokens` Edit, plus zone reads
- Consumer: one `terraform/bootstrap/` apply, then expiry
- Grants: P-1
- Created by: Operator
- Source: [`create-bootstrap-cloudflare-token.md`](../how-to/create-bootstrap-cloudflare-token.md)

### C-08: Grafana Cloud access-policy token

- Kind: access-policy token
- Scope: `stacks:read`, `stack-service-accounts:write`,
  `stack-plugins:read|write|delete`, `accesspolicies:read|write|delete`
- Consumer: one `terraform/bootstrap/` apply
- Grants: P-1
- Created by: Operator
- Source: [`create-grafana-git-sync-token.md`](../how-to/create-grafana-git-sync-token.md)

### C-10: Git Sync GitHub App

- Kind: GitHub App ID, installation ID, and private key
- Scope: `Contents`, `Pull requests`, and `Webhooks` write, installed
  on `alunduil-infrastructure` alone
- Consumer: A-11's Git Sync, for dashboard pull requests. Plan and apply
  both read the key
- Grants: P-2, P-3
- Created by: Operator
- Source: [`create-git-sync-github-app.md`](../how-to/create-git-sync-github-app.md)

### C-11: Tailscale trust credential (read)

- Kind: workload identity federation client ID
- Scope: tailnet read
- Consumer: the `tailscale` provider during plan
- Grants: P-2
- Created by: Operator
- Source: [`create-tailscale-trust-credential.md`](../how-to/create-tailscale-trust-credential.md)

### C-12: Tailscale trust credential (write)

- Kind: workload identity federation client ID
- Scope: tailnet write
- Consumer: the `tailscale` provider during apply
- Grants: P-3
- Created by: Operator
- Source: [`create-tailscale-trust-credential.md`](../how-to/create-tailscale-trust-credential.md)

### C-13: `GH_PROJECT_SYNC_TOKEN`

- Kind: GitHub classic personal access token
- Scope: `project`, `repo`, and `read:org`, as the account, without
  `workflow`. `repo` lets it write to every repository the account can. The
  sync only reads them
- Consumer: the hourly Projects v2 sync, from the `project-sync`
  environment on `main`
- Grants: the admin role, within those scopes
- Created by: Operator
- Source: [`create-github-project-sync-token.md`](../how-to/create-github-project-sync-token.md)
- Tracked by: #1069

### C-14: Web Analytics beacon

- Kind: Cloudflare site token, public and not a secret
- Scope: beacon submission for `blog.alunduil.com`
- Consumer: client-side JavaScript on the blog
- Grants: nothing, because the value is public and carries no access
- Created by: Operator
- Source: [`create-web-analytics-site.md`](../how-to/create-web-analytics-site.md)

### C-15: Cloudflare dynamic DNS token

- Kind: Cloudflare API token
- Scope: writes the `home.alunduil.com` A record. Its granted
  permissions are `Unverified`
- Consumer: `ddns-updater` on A-01
- Grants: P-4
- Created by: Operator
- Source: `None`
- Tracked by: #269

### C-16: Google Drive credential

- Kind: OAuth grant
- Scope: Drive read and write
- Consumer: A-01's Cloud Sync tasks
- Grants: P-4
- Created by: Operator
- Source: `None`

### C-17: Tailscale auth keys

- Kind: pre-authentication keys
- Scope: device enrolment
- Consumer: enrolling a host by hand, deliberately unmanaged
- Grants: P-1, when enrolling a host
- Created by: Operator
- Source: `None`

### C-18: `vscode-mcp-access`

- Kind: Grafana stack service account holding one token
- Scope: stack Viewer
- Consumer: `Unverified`
- Grants: P-1
- Created by: Operator
- Source: `None`

### C-19: TP-Link account

- Kind: Vendor account
- Scope: administration of A-04, including DHCP, DNS and the forwards
  that define T-2
- Consumer: the Deco app, through D-06
- Grants: P-1
- Created by: Operator
- Source: `None`

### C-20: `alunduil-infrastructure-fleet-management-ro`

- Kind: Grafana Cloud access-policy token
- Scope: `fleet-management:read` on the stack realm
- Consumer: `terraform plan` in CI
- Grants: P-2
- Created by: Terraform
- Source: `terraform/bootstrap/grafana_fleet_management.tf`

### C-21: `alunduil-infrastructure-fleet-management-rw`

- Kind: Grafana Cloud access-policy token
- Scope: `fleet-management:read` and `fleet-management:write` on the
  stack realm
- Consumer: `terraform apply` in CI, and `just alunduil`
- Grants: P-3, and P-1 through the break-glass path
- Created by: Terraform
- Source: `terraform/bootstrap/grafana_fleet_management.tf`

### C-22: `alunduil-infrastructure-alloy-push`

- Kind: Grafana Cloud access-policy token
- Scope: `logs:write` and `metrics:write` on the stack realm
- Consumer: alloy on A-01, as the `GCLOUD_RW_API_KEY` its Fleet
  Management pipelines authenticate with. No deployer reads it
- Grants: P-4
- Created by: Terraform
- Source: `terraform/bootstrap/grafana_alloy_push.tf`

### C-23: Home Assistant Credentials

- Kind: Google OAuth client, TV and limited input, in A-07
- Scope: the Google Calendar API. Its granted scopes are `Unverified`.
  Not agentic, so it can't call Google Workspace Model Context
  Protocol (MCP) servers. The agentic setting is permanent
- Consumer: A-02's Google Calendar integration
- Grants: P-4
- Created by: Operator
- Source: `None`

### C-24: Generative Language API Key

- Kind: Google Cloud API key, in A-07
- Scope: restricted to the Generative Language API
- Consumer: A-02's Google Gemini integration, inferred from the key's
  request traffic
- Grants: P-4
- Created by: Operator
- Source: `None`

### C-25: Hook-fix GitHub App

- Kind: GitHub App ID and private key
- Scope: `Contents` write on every repository it's installed on,
  without `Workflows`. It can create tags and Releases, replace Release
  assets, and push to unprotected branches. `renovate/**` is the only
  protected pattern that admits its pushes
- Consumer: `fix-renovate-hooks.yml` in `renovate-config`, called from
  repos with a `renovate` ruleset. It reads the App's ID and key from Secret
  Manager through the `hook-fix` workload identity pool, whose provider
  admits any ref of that workflow
- Grants: P-5
- Created by: Operator
- Source: [`create-hook-fix-github-app.md`](../how-to/create-hook-fix-github-app.md)

### C-26: Grafana GitHub data source App

- Kind: GitHub App ID, installation ID, and private key
- Scope: read-only `Actions`, `Contents`, `Issues`, `Metadata`, and
  `Pull requests`, installed on every `alunduil` repository
- Consumer: A-11's GitHub data source, for the delivery-metrics
  dashboards. Plan and apply read only the two IDs; the operator sets
  the key through the Grafana API
- Grants: GitHub data, to whoever queries A-11
- Created by: Operator
- Source: [`create-grafana-github-app.md`](../how-to/create-grafana-github-app.md)

### C-27: `alunduil-terraform-plan`

- Kind: GitHub App ID and private key
- Scope: read-only `Administration`, `Contents`, `Metadata`, and
  `Pages`, installed on every `alunduil` repository
- Consumer: the `integrations/github` provider in `terraform plan`.
  `terraform-plan.yml` reads the App's ID and key from Secret Manager as
  C-03
- Grants: P-2
- Created by: Operator
- Source: [`create-terraform-github-apps.md`](../how-to/create-terraform-github-apps.md)

### C-28: `alunduil-terraform-apply`

- Kind: GitHub App ID and private key
- Scope: `Administration`, `Contents`, and `Pages` write, installed on
  every `alunduil` repository
- Consumer: the `integrations/github` provider in `terraform apply`.
  `terraform-apply.yml` reads the App's ID and key from Secret Manager as
  C-04
- Grants: P-3
- Created by: Operator
- Source: [`create-terraform-github-apps.md`](../how-to/create-terraform-github-apps.md)

### C-29: `collection-json.hs` Hackage token

- Kind: Hackage API token
- Scope: authenticates as a Hackage user, so it can upload every package
  that user can. Hackage tokens have no per-package scope
- Consumer: `release.yml`, from the `hackage` environment
- Grants: uploads to D-12
- Created by: Operator
- Source: `None`

### C-30: `network-arbitrary` Hackage token

- Kind: Hackage API token
- Scope: authenticates as a Hackage user, so it can upload every package
  that user can. Hackage tokens have no per-package scope
- Consumer: `release.yml`, from the `hackage` environment
- Grants: uploads to D-12
- Created by: Operator
- Source: `None`

### C-32: `woodland-generators` release token

- Kind: GitHub fine-grained personal access token, with no expiry
- Scope: `Unverified`. It acts as the account, so it holds the admin role's
  ruleset bypasses
- Consumer: `release.yml`, for release-please
- Grants: the admin role, within its scope
- Created by: Operator
- Source: `None`
- Tracked by: #738

### C-33: Codecov upload tokens

- Kind: Codecov repository tokens, one per repository
- Scope: coverage uploads for `collection-json.hs`,
  `network-arbitrary`, `siren-json.hs`, and `woodland-generators`
- Consumer: each repository's CI
- Grants: nothing in the estate
- Created by: Operator
- Source: `None`

### C-34: `blog.alunduil.com analytics (RO)`

- Kind: Cloudflare API token
- Scope: Account Analytics Read on the account holding `alunduil.com`
- Consumer: none. The `blog` workload identity pool's provider admits only
  `pages.yml`, which the blog doesn't have
- Grants: nothing until a workflow reads it
- Created by: Terraform
- Source: `terraform/bootstrap/blog_analytics.tf`
- Tracked by: #1070

### C-35: `truenas-acme`

- Kind: Cloudflare API token
- Scope: Zone Read and DNS Write on `alunduil.com`
- Consumer: A-01's ACME DNS authenticator, which renews the
  `truenas.alunduil.com` web UI certificate. No deployer reads it
- Grants: P-4
- Created by: Terraform
- Source: `terraform/bootstrap/truenas_acme.tf`, set on A-01 from
  [`configure-truenas-acme-token.md`](../how-to/configure-truenas-acme-token.md)

## Maintenance

Adding or removing an asset, entry point, dependency, or credential
updates this register in the same pull request, and the verification
date at the top changes with it. A credential, or a change to who can
obtain one, also updates
[Credential reachability](../explanation/credential-reachability.md). IDs
aren't reused.
