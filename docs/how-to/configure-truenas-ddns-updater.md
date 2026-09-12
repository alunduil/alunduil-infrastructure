<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Configure the DDNS updater on TrueNAS

Keep `home.alunduil.com` pointed at the house's current public IP.
`plex.alunduil.com` is a CNAME to it, so this is the record the Plex
monitors resolve.

The updater is the community-train **DDNS Updater** app (`ddns-updater`,
from qdm12) running on TrueNAS. It owns `home.alunduil.com` outright:
Terraform declares every other record in the zone but not this one, and
a Terraform-managed copy would fight the app on every plan.

## Prerequisites

- A Cloudflare token with `Zone:Read` and `DNS:Edit` on `alunduil.com`.
  See [create-ddns-updater-token.md](create-ddns-updater-token.md).
- The `alunduil.com` zone ID, from the zone's **Overview** page in the
  Cloudflare dashboard.

## Install

Under **Apps → Discover Apps**, install **DDNS Updater** from the
`community` train. The defaults are fine apart from the DDNS
configuration block, which needs one entry:

- **Provider**: `cloudflare`.
- **Domain**: `home.alunduil.com`.
- **Zone ID**: the `alunduil.com` zone ID.
- **Token**: the `ddns-updater` token.
- **TTL**: `1` — Cloudflare's automatic TTL.
- **Proxied**: off. Plex connects to port 32400 directly, and
  Cloudflare's proxy only carries HTTP.

Leave the update period at `5m`. The app publishes the record itself
when it's absent, so there's nothing to seed by hand.

The web UI is published on port `30007` and reports each configured
domain's current IP and last update.

## Verify

```sh
dig +short home.alunduil.com @1.1.1.1
```

The answer should be the house's public IP. Resolving through a local
network can return a stale answer: a transparent resolver on the path
negative-caches a freshly created record for the zone's SOA minimum, so
check from off-network or against `1.1.1.1` rather than the LAN
resolver.

## What it publishes

Whatever public IP the box egresses from. During a WAN failover to the
mobile backup link that's a carrier-grade NAT address, which resolves
but accepts no inbound connections — Plex is unreachable from outside
the house until fibre returns, regardless of DNS.
