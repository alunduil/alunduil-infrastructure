# Estate review sources

Agent briefs for the estate-review skill.

## Every brief

- Call only what the source section below lists.
- The window, history range and due-soon horizon, as UTC dates.
- Every claim carries its evidence — job or run ID, timestamp, error string,
  the exact query — and whether the source is authoritative (configuration)
  or a proxy (logs, alerts).
- Report what failed or couldn't be retrieved, instead of inferring around it.
- Structure: broken, working, blind spots. About 800 words.

## UptimeRobot

Covers E-01 (Plex) and the Home Assistant and NanoPi-NEO3 heartbeats (D-04).

- Call only: `list-monitors`, `list-incidents` (page by cursor),
  `get-incident-details` for every incident, `get-monitor-details`,
  `get-monitor-stats`, `get-response-times`.
- The MCP server allows 20 requests a minute. On a rate-limit error, wait 60s
  and retry once.
- Report each monitor's status, and its uptime computed from incident
  durations — the stats call returns only an aggregate.
- Read the resolved IP from each Plex incident's request log, then classify:
  - All timeouts, and the IP leaves the fibre range `45.133.123.x` (an O2
    `82.132.x.x` address): failover to the mobile backup link, where DDNS
    publishes a CGNAT address.
  - `no route to host` → `connection refused` → `503` → `200`, IP stable:
    TrueNAS restarting.
  - 1–4 minutes of `connection timed out` on a stable fibre IP: a WAN blip.
    Saturday ~05:00Z (BST) or ~06:00Z (GMT) is most likely the Deco's
    weekly restart.
  - Cause `100001`: DNS resolution.
  - Anything else: unclassified.
- A Plex outage and a Home Assistant heartbeat miss in the same minute mean
  the whole home link dropped.
- Flag assets in the register with no monitor.
- The monitors' `domainExpireDate` lags renewals. Take the domain's
  expiry from RDAP.

## TrueNAS

Covers A-01, A-12 and D-02's backups. Call only these MCP tools: `system_info`,
`list_alerts`, `query_jobs` (filter by state FAILED and ABORTED, then by
RUNNING), `query_pools`, `get_scrub_status`, `query_apps`, `check_updates`,
`update_status`, `query_boot_environments`, `get_system_metrics`,
`get_disk_metrics`.

- `query_snapshots` stays off the list: it never finishes on this box's
  CPU.
- The middleware keeps only its latest 1,000 jobs, a few days at the
  15-minute cloud-sync cadence. Say where coverage starts.
- Report jobs RUNNING for more than a day.
- The MCP server has no cloud-sync or rsync configuration reader. Job error
  strings are the evidence; the per-task log in the UI holds the detail.
- A `Software NMI` IPMI alert within minutes of a boot marks a reboot. One
  with no reboot near it is the hang warning.
- Certificates: report the `truenas-acme-cert` expiry and any
  `certificate.renew_certs` failure.
- A `RESTAPIUsage` alert from `192.168.68.58` is tracked by #728, which
  confirms whether it's penguin's fallback when the MCP server fails.

## Grafana Cloud

Covers telemetry from A-01, A-02, A-03, A-06 and A-05 (D-11). Call only
`gcx api` GET requests, setting `GRAFANA_ORG_ID=1` on each:

```bash
ds=/api/datasources/proxy/uid
GRAFANA_ORG_ID=1 gcx api -o json \
  "$ds/grafanacloud-logs/loki/api/v1/query_range?query=..." 2>/dev/null
GRAFANA_ORG_ID=1 gcx api -o json \
  "$ds/grafanacloud-prom/api/v1/query_range?query=..." 2>/dev/null
```

URL-encode queries. Keep `2>/dev/null`, so the `gcx` hint line stays out of
the JSON. Loki caps a query at 30 days.

What ships where:

- TrueNAS: Loki `{host="truenas"}`, syslog at info level plus audit;
  Prometheus `up{job="truenas-scale"}`, Netdata scraped by alloy.
- Home Assistant: Loki `{hostname="homeassistant"}`; Prometheus `hass_*`.
- slzb-mr4u: Loki, a heartbeat about every 30 minutes.
- penguin: Prometheus `integrations/unix`, Loki `host="penguin"`.
- alloy: `alloy_build_info`.
- NanoPi-NEO3: confirm whether it ships anything.

Report:

- Gaps in `up` and silences in log volume, each matched to a cause (app
  upgrade, reboot, power-off) or left unexplained.
- Error volume per host per day, and the top recurring messages per host
  with counts.
- DNS failures: `|~ "(?i)i/o timeout|SERVFAIL|no such host"`, and the
  resolver each one names.
- TrueNAS: reboot and shutdown audit events, OOM kills, `zed`, `cloudsync`
  errors including `rateLimitExceeded`, container restarts.
- Home Assistant: automation errors by entity and reason, integrations
  failing, Zigbee2MQTT disconnects, Nabu Casa connection errors, IP bans.
- Alert rules: what fired, and anything in an error or no-data state.

Adaptive Metrics aggregates labels away on `hass_*_info` and change-time
series. A `<aggregated>` label is a known gap, not an empty result.

## GitHub

Covers A-09 and every repository in `terraform/*/repositories.tf`. Call only
`gh api` GET requests and `gh search`. Both use REST, which keeps the shared
GraphQL budget free.

- Failed, cancelled and timed-out Actions runs per repository in the window
  (`/repos/{r}/actions/runs?created=>=YYYY-MM-DD`). Fetch the failing job's
  log tail for each recurring failure (`gh api --allow-escape-sequences
  .../actions/jobs/{id}/logs`).
- This repository: every Terraform Apply on `main`. A failed apply is drift
  until a later apply succeeds.
- Scheduled workflows that didn't run, and workflows not in the `active`
  state.
- Renovate: open PRs opened before the window or failing checks, and the Dependency
  Dashboard issue's error and rate-limit sections. Group a failure repeated
  across repositories as one finding.
- Open Dependabot, code scanning and secret scanning alerts. A 403 or 404
  means the feature is off.

## Network and cloud

Call only the read tools and commands named below.

Cloudflare (A-08): the Cloudflare MCP servers' read tools. The DNS report
caps at 6 hours on this plan, so use GraphQL `dnsAnalyticsAdaptiveGroups`
with explicit `datetime_geq` and `datetime_leq` covering the window. GraphQL
accepts the whole window in one query. No dataset exposes DNSSEC. Report
response codes, DNSSEC status, and zone or DNSSEC settings modified in the
window. Match any modification against this repository's commits to `main`.

Domain: RDAP `https://rdap.verisign.com/com/v1/domain/alunduil.com` for
expiry. Renewal is automatic at Squarespace; report the date only.

Google Cloud (A-07): `gcloud logging read 'severity>=ERROR' --freshness=7d
--project=alunduil`.

Tailscale (A-10): `tailscale status --json`. Report offline devices, node keys
expiring within the due-soon horizon or already expired, and whether both
exit nodes and `homeassistant` are online. Offline phones, tablets and
Chromebooks with expired keys are known devices that renew their keys on
their next sign-in; list them, don't flag them.
