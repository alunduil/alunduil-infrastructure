<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Asset register

Every host, device, service, and operator credential in the personal
estate.

Verified 2026-09-12.

## Scope

Covers the home network, the off-site host, the operator workstation,
and the cloud and identity services this repository provisions or
depends on.

Out of scope:

- The MCP server fleet and the workstation's own configuration, which
  belong to `alunduil/alunduil-chezmoi`.
- Hardware not yet acquired.
- Secret values and their storage paths.

## Field conventions

Entries carry the same fields in the same order. An entry names
`Location` or `Owner` only to override the default its section states.

`Address` carries the handle that reaches the asset. A LAN address
appears only where something depends on that exact value. Every lease
here is the Deco's to reassign, so elsewhere the name is the stable
handle and the address follows from it.

Three values carry a fixed meaning:

| Value | Meaning |
| --- | --- |
| `None` | Nothing of this kind exists for the asset |
| `Not applicable` | The field doesn't apply to this kind of asset |
| `Unverified` | Out of reach of the repository and of a live query |

Criticality states what breaks on loss of the asset:

| Tier | Meaning |
| --- | --- |
| High | A service in daily use stops, with no substitute |
| Medium | Noticeable loss, worked around within a day |
| Low | Inconvenience only |

Classification states what the asset holds:

| Label | Meaning |
| --- | --- |
| Personal | Household media, documents, and home telemetry |
| Operational | Credentials, configuration, infrastructure state |
| Public | Content published to the internet |

## Name resolution

An `Address` field names the handle; this section names where each
kind of name comes from.

| Suffix or zone | Comes from | Reachable from |
| --- | --- | --- |
| `tail3af06.ts.net` | Tailscale MagicDNS | any tailnet device |
| `.local` | the home network | LAN clients |
| `alunduil.com` | Cloudflare | the public internet |
| anything else | Deco, relaying to Quad9 | LAN clients |

LAN names follow the DHCP reservations held in the Deco app. Nothing
in this repository declares them, so the app is the place to add, read,
or change one.

`penguin` resolves no LAN name. It sits behind ChromeOS's NAT on a
segment of its own rather than on the LAN, so it reaches LAN hosts by
tailnet name or by address, which is how the TrueNAS MCP server
connects.

`truenas.alunduil.com` appears on the TrueNAS web certificate and has
no DNS record. That certificate comes from an ACME DNS-01 challenge,
which proves zone control without publishing an address.

## Hosts and devices

alunduil owns every host below, and each sits in London unless its
entry says otherwise.

### `truenas`

- Address: `truenas.local`; `truenas-scale.tail3af06.ts.net`
- Role: NAS and application host; Tailscale subnet router advertising
  `192.168.68.0/22`, and an exit node
- Runs: Plex, Netdata, alloy, Tailscale, `ddns-updater`, Scrutiny
- Hardware: TrueNAS Mini 3.0-E, Atom C3338, 16 GiB ECC memory, four
  disks in one `raidz2` vdev
- OS: TrueNAS 25.10.7
- Criticality: High
- Classification: Personal, Operational
- Monitoring: Grafana Cloud metrics (`truenas-scale`) and logs
  (`truenas`); Netdata; Scrutiny SMART; UptimeRobot through the Plex
  endpoints
- Backup: configuration bundle to Google Drive on a schedule, per
  [the config backup how-to](../how-to/configure-truenas-config-backup.md)

### `homeassistant`

- Address: `192.168.68.56`, which `grafana/air-quality.json` pins in
  four panel queries; `homeassistant.tail3af06.ts.net`
- Role: home automation hub
- Runs: Zigbee2MQTT, Mosquitto, Matter server, alloy, Tailscale, SSH,
  File editor
- OS: Home Assistant OS, version `Unverified`
- Criticality: Medium
- Classification: Personal
- Monitoring: Grafana Cloud metrics (`home-assistant`) and journal
  logs; UptimeRobot heartbeat
- Backup: `Unverified`

### `slzb-mr4u`

- Address: `Unverified`
- Role: Zigbee and Thread radio coordinator
- OS: `Unverified`
- Criticality: Medium
- Classification: Personal
- Monitoring: syslog to Loki (`slzb-mr4u`)
- Backup: `None`; configuration lives on the device

### Deco mesh

- Address: `192.168.68.1`, fixed by its gateway role, serving
  `192.168.68.0/22`
- Role: router, Wi-Fi mesh, DHCP, and DNS relay to Quad9 over DNS over
  HTTPS
- OS: TP-Link Deco; model and firmware `Unverified`
- Criticality: High
- Classification: Operational
- Monitoring: `None`
- Backup: `Unverified`

### `nanopi-neo3`

- Address: `nanopi-neo3.tail3af06.ts.net`; DHCP on its local network
- Role: Tailscale exit node presenting a US address
- OS: Armbian, version `Unverified`
- Location: American Midwest, in a household that isn't alunduil's
- Owner: alunduil, administered remotely from London
- Criticality: Low
- Classification: Operational
- Monitoring: UptimeRobot heartbeat. Grafana Cloud shipping is absent;
  see issue #473
- Backup: hourly `rclone` of package selections and `/home` to Google
  Drive
- Recovery:
  [ADR 0002](../adr/0002-build-nanopi-neo3-recovery-image-with-armbian.md)

### `penguin`

- Address: `penguin.tail3af06.ts.net`
- Role: operator workstation, running break-glass Terraform applies,
  `chezmoi`, and Claude Code
- OS: Debian under Crostini, version `Unverified`
- Criticality: Medium
- Classification: Operational
- Monitoring: Grafana Cloud `integrations/unix` and
  `integrations/process`; zellij logs to Loki
- Backup: `Unverified`

## Cloud and identity services

alunduil owns every account below.

### Google Cloud

- Identifier: project `alunduil`, region `europe-west1`
- Role: Terraform state bucket, Secret Manager, the workload identity
  federation pool for CI, and audit logging
- Criticality: High
- Classification: Operational
- Monitoring: Grafana Cloud queries Cloud Monitoring live at dashboard
  time; data-access audit logs are enabled for storage and Secret
  Manager
- Backup: Terraform state is versioned in its bucket

### Cloudflare

- Identifier: zone `alunduil.com`, DNSSEC active
- Role: authoritative DNS and zone settings
- Criticality: High
- Classification: Public
- Monitoring: `None` on the zone; UptimeRobot covers the records that
  resolve to home
- Backup: every record except `home.alunduil.com` is declared in
  `terraform/alunduil/dns.tf`

### Squarespace

- Identifier: registrar for `alunduil.com`
- Role: domain registration and the DS records for DNSSEC
- Criticality: High
- Classification: Public
- Monitoring: `None`
- Backup: `Not applicable`

### GitHub

- Identifier: account `alunduil`
- Role: source of record for every managed repository, and the CI that
  applies this infrastructure
- Criticality: High
- Classification: Operational, Public
- Monitoring: `None`
- Backup: repositories are cloned across the estate; settings are
  declared in `terraform/alunduil/repositories.tf`

### Tailscale

- Identifier: tailnet `tail3af06.ts.net`
- Role: private network joining every host above
- Settings: device approval on, key duration 180 days, MagicDNS on,
  HTTPS certificates on, global nameservers pinned to Quad9. Both exit
  nodes carry per-device key-expiry exemptions set outside Terraform
- Criticality: High
- Classification: Operational
- Monitoring: `None`; network flow logging is off
- Backup: the policy file is declared in
  `terraform/alunduil/tailscale-acl.hujson`

### Grafana Cloud

- Identifier: stack `alunduil`, region `prod-gb-south-1`
- Role: metrics, logs, traces, profiles, and dashboards
- Criticality: Medium
- Classification: Operational
- Monitoring: `Not applicable` — this is the monitoring system
- Backup: dashboards sync to the `grafana/` directory of this
  repository through Git Sync

### UptimeRobot

- Identifier: four monitors — Plex over HTTP, Plex over HTTPS, a Home
  Assistant heartbeat, and a NanoPi-NEO3 heartbeat
- Role: external availability checks
- Criticality: Medium
- Classification: Operational
- Monitoring: `Not applicable`
- Backup: `None`; monitors are configured by hand

### Google Drive

- Identifier: `Unverified`
- Role: backup destination for the TrueNAS configuration bundle,
  Google Takeout archives, and the NanoPi-NEO3
- Criticality: High
- Classification: Personal, Operational
- Monitoring: `None`
- Backup: `Not applicable` — this is the backup destination

## Tailnet clients

Devices holding tailnet membership that run no service. The fields
above don't apply.

| Node | Platform | Account | Key |
| --- | --- | --- | --- |
| `brya` | Android on ChromeOS | alunduil | Expires 2027-01-07 |
| `pixel-9-pro-fold` | Android | alunduil | Expires 2026-09-23 |
| `tabultrac` | Android | alunduil | Expires 2026-10-16 |
| `rogxboxallyx` | Windows | alunduil | Expires 2026-12-15 |
| `pixel-9a` | Android | partner | Expired 2026-08-02 |
| `chromeos-google-octopus` | Android | partner | Expired 2025-11-21 |

## Credentials

Every Active operator and API credential, with the consumer that reads
it. `Source` names the Terraform file that declares a credential, or
the how-to that creates it.

A credential live in a provider console with no entry below is an
orphan. None is recorded at the verification date.

### Provisioned by Terraform

`terraform apply` creates and rotates each of these.

#### alunduil-infrastructure deployer (RO)

- Kind: Cloudflare API token
- Scope: Zone Read, DNS Read, and Zone Settings Read on `alunduil.com`
- Consumer: `terraform plan` in CI
- Source: `terraform/bootstrap/cloudflare_tokens.tf`

#### alunduil-infrastructure deployer (RW)

- Kind: Cloudflare API token
- Scope: Zone Read, DNS Write, and Zone Settings Write on
  `alunduil.com`
- Consumer: `terraform apply` in CI, and `just alunduil`
- Source: `terraform/bootstrap/cloudflare_tokens.tf`

#### `github-deployer-ro`

- Kind: Google Cloud service account
- Scope: the `githubDeployerPlanner` custom role, and object read on
  the state bucket
- Consumer: `terraform plan` in CI, through workload identity
  federation
- Source: `terraform/bootstrap/service_account_github_deployer_ro.tf`

#### `github-deployer-rw`

- Kind: Google Cloud service account
- Scope: the `githubDeployerApplier` custom role, and object admin on
  the state bucket
- Consumer: `terraform apply` in CI, restricted to `refs/heads/main`
- Source: `terraform/bootstrap/service_account_github_deployer_rw.tf`

#### `grafana-gcp-reader`

- Kind: Google Cloud service account key
- Scope: `monitoring.viewer`, `logging.viewer`, `logging.viewAccessor`
- Consumer: the Cloud Monitoring data source in Grafana Cloud
- Source: `terraform/bootstrap/grafana_gcp_reader.tf`

#### `alunduil-infrastructure-provisioner`

- Kind: Grafana stack service account token
- Scope: stack Admin
- Consumer: the Grafana resources in `terraform/alunduil/`
- Source: `terraform/bootstrap/grafana.tf`

### Created by hand

Each needs an operator in a console; no apply rotates them.

#### Master Cloudflare token

- Kind: Cloudflare API token, time-limited
- Scope: `User:API Tokens` Edit, plus zone reads
- Consumer: one `terraform/bootstrap/` apply, then expiry
- Source: [`create-master-cloudflare-token.md`](../how-to/create-master-cloudflare-token.md)

#### Grafana Cloud access-policy token

- Kind: access-policy token
- Scope: `stacks:read`, `stack-service-accounts:write`
- Consumer: one `terraform/bootstrap/` apply
- Source: [`create-grafana-git-sync-token.md`](../how-to/create-grafana-git-sync-token.md)

#### Deployer GitHub App

- Kind: GitHub App ID and private key
- Scope: installed across the managed repositories
- Consumer: the `integrations/github` provider in CI
- Source: [`create-deployer-github-app.md`](../how-to/create-deployer-github-app.md)

#### Git Sync GitHub App

- Kind: GitHub App ID, installation ID, and private key
- Scope: installed on `alunduil-infrastructure` alone
- Consumer: Grafana Git Sync, for dashboard pull requests
- Source: [`create-git-sync-github-app.md`](../how-to/create-git-sync-github-app.md)

#### Tailscale trust credential (read)

- Kind: workload identity federation client ID
- Scope: tailnet read
- Consumer: the `tailscale` provider during plan
- Source: [`create-tailscale-trust-credential.md`](../how-to/create-tailscale-trust-credential.md)

#### Tailscale trust credential (write)

- Kind: workload identity federation client ID
- Scope: tailnet write
- Consumer: the `tailscale` provider during apply
- Source: [`create-tailscale-trust-credential.md`](../how-to/create-tailscale-trust-credential.md)

#### `GH_PROJECT_SYNC_TOKEN`

- Kind: GitHub classic personal access token
- Scope: Projects v2 write
- Consumer: the Projects v2 sync workflow
- Source: [`create-github-project-sync-token.md`](../how-to/create-github-project-sync-token.md)

#### Web Analytics beacon

- Kind: Cloudflare site token; public, and no secret
- Scope: beacon submission for `blog.alunduil.com`
- Consumer: client-side JavaScript on the blog
- Source: [`create-web-analytics-site.md`](../how-to/create-web-analytics-site.md)

#### Cloudflare DDNS token

- Kind: Cloudflare API token
- Scope: writes the `home.alunduil.com` A record; its granted
  permissions are `Unverified`
- Consumer: `ddns-updater` on `truenas`
- Source: `None`. Issue #269 tracks writing a how-to

#### Google Drive credential

- Kind: OAuth grant
- Scope: Drive read and write
- Consumer: the TrueNAS Cloud Sync tasks
- Source: `None`

#### Tailscale auth keys

- Kind: pre-authentication keys
- Scope: device enrolment
- Consumer: enrolling a host by hand; deliberately unmanaged
- Source: `None`

## Maintenance

Adding or removing a host, device, service, or credential updates this
register in the same pull request, and the verification date above
changes with it.
