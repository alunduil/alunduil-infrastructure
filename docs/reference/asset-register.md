<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Asset register

The assets in the personal estate, the zones they're exposed to, the
principals that act on them, and the credentials that grant those
principals.

Verified 2026-09-13.

## Scope

Follows the enumeration [OWASP's threat modeling
process](https://community.owasp.org/Threat_Modeling_Process) asks for
ahead of a data flow diagram. The network map, the data-flow diagram,
and the threat model cite entries here by ID.

Out of scope:

- Component inventory fields — model, serial number, firmware version,
  physical location, purchase details. Those live in a private Notion
  inventory. Recording them twice would be duplicate accounting.
- Criticality tiers and data classification, which belong to a
  reliability map rather than a threat model.
- The workstation's own configuration, which belongs to
  `alunduil/alunduil-chezmoi`.
- Secret values and their storage paths.
- Hardware identifiers. A MAC address identifies a device globally and
  for its lifetime, and public wireless-survey databases index the
  addresses routers broadcast, so one recorded here would tie this
  repository to a street address.

An `Unverified` field was out of reach of both the repository and a
live query at the verification date.

## Zones

Network positions, ordered by trust. An asset's exposure is the
least-trusted zone with a path to it, and no asset has more than one.

| ID | Name | Who is in it |
| --- | --- | --- |
| T-1 | Public internet | Anyone |
| T-2 | LAN | Anything on `192.168.68.0/22` |
| T-3 | Tailnet | Devices approved onto the tailnet |

T-2 is one flat segment. Around twenty devices answer on it, of which
eleven advertise no service and this register doesn't identify them.

## Principals

Who acts, as distinct from where they act. Credentials grant these.

| ID | Name | Who holds it |
| --- | --- | --- |
| P-1 | Operator | alunduil, at a console or the workstation |
| P-2 | CI plan | A pull request against this repository |
| P-3 | CI apply | A push to `refs/heads/main` |
| P-4 | Host service | A service on a host, holding its own credential |

P-2 and P-3 are separate because a pull request supplies the workflow
that runs. They reach different credentials by design; E-04 records
what keeps a fork out of both.

## Trust boundaries

Privilege changes that aren't a zone edge. The boundaries between zones
are implied by their order; these sit inside a single host.

| ID | Boundary | Separates |
| --- | --- | --- |
| B-1 | Container isolation on A-01 | A-12 and five other apps from A-01 |
| B-2 | Add-on isolation on A-02 | Eight add-ons from A-02 |

B-1 isn't one boundary. What crossing it means depends on which
container is on the far side.

A-12 declares no host mounts, takes the media library read-only, runs
on a bridge rather than sharing the host's network, and names a
non-root user, so a T-1 client arriving at E-01 lands somewhere that
can't write what it serves.

Netdata mounts `/proc`, `/sys`, and the host's Docker socket, holds
`SYS_ADMIN`, `SYS_PTRACE` and `SYS_RAWIO`, and runs as root. A socket
that can start a privileged container is host authority, so B-1
separates Netdata from A-01 in name only and E-11 reaches A-01 itself.

Scrutiny sits between them. It holds no Docker socket, but runs as root
with `/dev` and `/run/udev` mounted and `MKNOD` held, which is raw
access to the disks A-01 exists to hold. Its two ports answer T-2 as
E-12.

Every one of these catalogue entries describes running as root. A-12's
configuration overrides that with a named user; Netdata's and
Scrutiny's carry no override.

alloy, Tailscale, and `ddns-updater` stay unchecked. Each keeps a
credential in its application configuration, so establishing their
boundaries means reading those values. All of B-2 is unchecked too.

## Assets

Hosts and devices alunduil owns, and accounts this repository
configures. P-1 administers every one; an entry names `Administered by`
only to add a principal beyond it.

### A-01 — `truenas`

- Description: NAS and application host. Runs Plex, Netdata, alloy,
  Tailscale, `ddns-updater`, and Scrutiny. Advertises
  `192.168.68.0/22` to the tailnet as a subnet router, and offers an
  exit node
- Names: `truenas.local`, `truenas-scale.tail3af06.ts.net`
- Exposed to: T-2, via E-05. A-12 carries its only path from T-1

### A-02 — `homeassistant`

- Description: home automation hub. Runs Zigbee2MQTT, Mosquitto, a
  Matter server, an OpenThread Border Router, alloy, Tailscale, SSH,
  and the File editor. Every automation in the house runs here
- Names: `192.168.68.56`, `homeassistant.tail3af06.ts.net`
- Exposed to: T-1, via E-03

### A-03 — `slzb-mr4u`

- Description: Zigbee and Thread radio coordinator, carrying every
  Zigbee message the house sends. A-02's Zigbee2MQTT depends on it.
  A-02 reaches the Thread radio the same way, but no Thread devices
  are paired, so that half is unexercised
- Names: `SLZB-MR4U.local`
- Exposed to: T-2, via E-07

### A-04 — Deco mesh

- Description: router, Wi-Fi mesh, DHCP, and DNS relay. Three units.
  Owns the DHCP reservations that LAN names follow, and the app that
  holds them is the only place they exist
- Names: `192.168.68.1`, fixed by its gateway role
- Exposed to: T-1, at its WAN interface

### A-05 — `nanopi-neo3`

- Description: Tailscale exit node presenting a US address. Sits in
  the American Midwest in a household that isn't alunduil's, and is
  administered remotely from London. Recovery is
  [ADR 0002](../adr/0002-build-nanopi-neo3-recovery-image-with-armbian.md)
- Names: `nanopi-neo3.tail3af06.ts.net`
- Exposed to: T-3, via E-09

### A-06 — `penguin`

- Description: operator workstation, a Crostini container. Runs
  break-glass Terraform applies, `chezmoi`, and Claude Code, so it
  holds the operator's credentials
- Names: `penguin.tail3af06.ts.net`
- Exposed to: no inbound path; it initiates its own connections

### A-07 — Google Cloud

- Description: holds the Terraform state bucket, Secret Manager, the
  workload identity federation pool, and the audit log configuration
- Names: project `alunduil`, in `europe-west1`
- Exposed to: T-1. Its API is public, so a leaked credential is
  usable from anywhere
- Administered by: P-2, P-3

### A-08 — Cloudflare

- Description: authoritative DNS and zone settings, DNSSEC active.
  Every record except `home.alunduil.com` is
  declared in `terraform/alunduil/dns.tf`; that one is written by
  `ddns-updater` on A-01
- Names: zone `alunduil.com`
- Exposed to: T-1, both as a resolver and through a public API
- Administered by: P-2, P-3

### A-09 — GitHub

- Description: source of record for every managed repository, and the
  runtime that applies this infrastructure. Repository settings are
  declared in `terraform/alunduil/repositories.tf`
- Names: account `alunduil`
- Exposed to: T-1, via E-02 and E-04
- Administered by: P-2, P-3

### A-10 — Tailscale

- Description: private network joining every host above. Device
  approval on, key duration 180 days, MagicDNS
  on, HTTPS certificates on, global nameservers pinned to Quad9. Both
  exit nodes carry per-device key-expiry exemptions set outside
  Terraform. The policy file is declared in
  `terraform/alunduil/tailscale-acl.hujson`
- Names: tailnet `tail3af06.ts.net`
- Exposed to: T-1. Its API is public; T-3 is what the tailnet grants,
  not what reaches the account
- Administered by: P-2, P-3

### A-11 — Grafana Cloud

- Description: metrics, logs, traces, profiles, and dashboards, syncing
  from this repository's `grafana/` directory through Git Sync
- Names: stack `alunduil`, in `prod-gb-south-1`
- Exposed to: T-1. Its API is public
- Administered by: P-3

### A-12 — Plex

- Description: media server, running as a container on A-01 and reading
  the library from its pool read-only. The only asset here that T-1
  reaches without holding a credential. Compromising it yields the
  container rather than A-01, across B-1
- Names: `plex.alunduil.com`, resolving through `home.alunduil.com`
- Exposed to: T-1, via E-01

## Entry points

Interfaces where data arrives. Each names the asset a client actually
reaches: the container where B-1 holds, and the host where it doesn't,
which is why E-01 names A-12 and E-11 names A-01.

| ID | Interface | Asset | Reachable from |
| --- | --- | --- | --- |
| E-01 | Plex on 32400, over HTTP and HTTPS | A-12 | T-1 |
| E-02 | `blog.alunduil.com`, served by GitHub Pages | A-09 | T-1 |
| E-03 | The Nabu Casa remote interface | A-02 | T-1 |
| E-04 | Pull requests against a public repository | A-09 | T-1 |
| E-05 | Web interface on 443, SMB on 445, HTTP on 80 | A-01 | T-2 |
| E-06 | Home Assistant on 8123 | A-02 | T-2 |
| E-07 | Web interface on 80, `_slzb-06._tcp` on 7638 | A-03 | T-2 |
| E-08 | Administration through the vendor's app | A-04 | T-2 |
| E-09 | Services published to the tailnet | A-01, A-02 | T-3 |
| E-10 | The `home.alunduil.com` A record | A-08 | P-1 |
| E-11 | Netdata on 20489 | A-01 | T-2 |
| E-12 | Scrutiny on 31054 and 31055 | A-01 | T-2 |

E-01 is the widest. It publishes A-12 to anyone who resolves the name.
Plex asks a client from T-1 to sign in, but its allowed-networks
setting covers every RFC 1918 range, so a client already in T-2 reaches
it without doing so, the devices T-2 can't identify included.

E-04 reaches P-2's credentials because `terraform-plan.yml` triggers on
`pull_request` with no environment gate. What keeps a stranger out is
`terraform/bootstrap/github_oidc.tf`, whose pool requires
`assertion.repository == 'alunduil/alunduil-infrastructure'`, so a
token minted for a fork matches nothing. A branch pull request inside
this repository does reach the read-only deployer.

## External dependencies

Services outside our control, and what leaves to them.

| ID | Service | What leaves |
| --- | --- | --- |
| D-01 | Nabu Casa | A-02's backups, and its remote interface traffic |
| D-02 | Google Drive | A-01's backups, Takeout archives, A-05's `/home` |
| D-03 | Quad9 | Every DNS query from A-10, and from T-2 via A-04 |
| D-04 | UptimeRobot | Probes against E-01; heartbeats from A-02, A-05 |
| D-05 | Squarespace | Registrar for `alunduil.com`, holding its DS records |

A-11 is an asset rather than a dependency because Terraform configures
it, but telemetry from A-01, A-02, A-03, and A-06 leaves to it all the
same.

## Credentials

The credentials this repository declares or documents, with the
consumer that reads each and the trust level it grants. `Source` names
the Terraform file that declares a credential, or the how-to that
creates it.

A credential live in a provider console with no entry below is an
orphan. Only enumerating that console finds one, which the repository
can't do on its own. At the verification date that enumeration had
covered Grafana Cloud alone, where it found C-18. Nobody has
enumerated Cloudflare, Google Cloud, GitHub, or Tailscale.

### Provisioned by Terraform

`terraform apply` creates and rotates each of these.

#### C-01 — `alunduil-infrastructure deployer (RO)`

- Kind: Cloudflare API token
- Scope: Zone Read, DNS Read, and Zone Settings Read on `alunduil.com`
- Consumer: `terraform plan` in CI
- Grants: P-2
- Source: `terraform/bootstrap/cloudflare_tokens.tf`

#### C-02 — `alunduil-infrastructure deployer (RW)`

- Kind: Cloudflare API token
- Scope: Zone Read, DNS Write, and Zone Settings Write on
  `alunduil.com`
- Consumer: `terraform apply` in CI, and `just alunduil`
- Grants: P-3, and P-1 through the break-glass path
- Source: `terraform/bootstrap/cloudflare_tokens.tf`

#### C-03 — `github-deployer-ro`

- Kind: Google Cloud service account
- Scope: the `githubDeployerPlanner` custom role, and object read on
  the state bucket
- Consumer: `terraform plan` in CI, through workload identity
  federation
- Grants: P-2
- Source: `terraform/bootstrap/service_account_github_deployer_ro.tf`

#### C-04 — `github-deployer-rw`

- Kind: Google Cloud service account
- Scope: the `githubDeployerApplier` custom role, and object admin on
  the state bucket
- Consumer: `terraform apply` in CI, restricted to `refs/heads/main`
- Grants: P-3
- Source: `terraform/bootstrap/service_account_github_deployer_rw.tf`

#### C-05 — `grafana-gcp-reader`

- Kind: Google Cloud service account key
- Scope: `monitoring.viewer`, `logging.viewer`, `logging.viewAccessor`
- Consumer: A-11's Cloud Monitoring data source
- Grants: P-1
- Source: `terraform/bootstrap/grafana_gcp_reader.tf`

#### C-06 — `alunduil-infrastructure-provisioner`

- Kind: Grafana stack service account token
- Scope: stack Admin
- Consumer: the Grafana resources in `terraform/alunduil/`
- Grants: P-3
- Source: `terraform/bootstrap/grafana.tf`

### Created by hand

Each needs an operator in a console; no apply rotates them.

#### C-07 — Master Cloudflare token

- Kind: Cloudflare API token, time-limited
- Scope: `User:API Tokens` Edit, plus zone reads
- Consumer: one `terraform/bootstrap/` apply, then expiry
- Grants: P-1
- Source: [`create-master-cloudflare-token.md`](../how-to/create-master-cloudflare-token.md)

#### C-08 — Grafana Cloud access-policy token

- Kind: access-policy token
- Scope: `stacks:read`, `stack-service-accounts:write`
- Consumer: one `terraform/bootstrap/` apply
- Grants: P-1
- Source: [`create-grafana-git-sync-token.md`](../how-to/create-grafana-git-sync-token.md)

#### C-09 — Deployer GitHub App

- Kind: GitHub App ID and private key
- Scope: installed across the managed repositories
- Consumer: the `integrations/github` provider in CI
- Grants: P-2, P-3
- Source: [`create-deployer-github-app.md`](../how-to/create-deployer-github-app.md)

#### C-10 — Git Sync GitHub App

- Kind: GitHub App ID, installation ID, and private key
- Scope: installed on `alunduil-infrastructure` alone
- Consumer: A-11's Git Sync, for dashboard pull requests
- Grants: P-3
- Source: [`create-git-sync-github-app.md`](../how-to/create-git-sync-github-app.md)

#### C-11 — Tailscale trust credential (read)

- Kind: workload identity federation client ID
- Scope: tailnet read
- Consumer: the `tailscale` provider during plan
- Grants: P-2
- Source: [`create-tailscale-trust-credential.md`](../how-to/create-tailscale-trust-credential.md)

#### C-12 — Tailscale trust credential (write)

- Kind: workload identity federation client ID
- Scope: tailnet write
- Consumer: the `tailscale` provider during apply
- Grants: P-3
- Source: [`create-tailscale-trust-credential.md`](../how-to/create-tailscale-trust-credential.md)

#### C-13 — `GH_PROJECT_SYNC_TOKEN`

- Kind: GitHub classic personal access token
- Scope: Projects v2 write
- Consumer: the Projects v2 sync workflow
- Grants: P-3
- Source: [`create-github-project-sync-token.md`](../how-to/create-github-project-sync-token.md)

#### C-14 — Web Analytics beacon

- Kind: Cloudflare site token; public, and no secret
- Scope: beacon submission for `blog.alunduil.com`
- Consumer: client-side JavaScript on the blog
- Grants: nothing; the value is public and carries no access
- Source: [`create-web-analytics-site.md`](../how-to/create-web-analytics-site.md)

#### C-15 — Cloudflare DDNS token

- Kind: Cloudflare API token
- Scope: writes the `home.alunduil.com` A record; its granted
  permissions are `Unverified`
- Consumer: `ddns-updater` on A-01
- Grants: P-4
- Source: `None`. Issue #269 tracks writing a how-to

#### C-16 — Google Drive credential

- Kind: OAuth grant
- Scope: Drive read and write
- Consumer: A-01's Cloud Sync tasks
- Grants: P-4
- Source: `None`

#### C-17 — Tailscale auth keys

- Kind: pre-authentication keys
- Scope: device enrolment
- Consumer: enrolling a host by hand; deliberately unmanaged
- Grants: P-1, when enrolling a host
- Source: `None`

#### C-18 — `vscode-mcp-access`

- Kind: Grafana stack service account holding one token
- Scope: stack Viewer
- Consumer: `Unverified`
- Grants: P-1
- Source: `None`

## Maintenance

Adding or removing an asset, entry point, dependency, or credential
updates this register in the same pull request, and the verification
date above changes with it. IDs aren't reused.
