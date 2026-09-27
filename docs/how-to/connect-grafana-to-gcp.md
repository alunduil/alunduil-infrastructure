<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Connect Grafana Cloud to GCP metrics and audit logs

Terraform creates the data source, the log-based metric, and the alert rule. It
can't set the data source's service-account key: that would persist the key in
bucket-readable state, so you set it through the Grafana API instead. Run this
when the data source is first created, when a UID or type change recreates it,
and on key rotation; routine applies leave the key untouched.

## Prerequisites

- `just bootstrap` and `terraform/alunduil` both applied.
- `gcloud` and `jq` available, authenticated as an identity that can read the
  `grafana-gcp-reader-key` secret.
- `gcx` logged in to the `alunduil` stack. It carries the Grafana credential, so
  the script needs no API token of its own.

## Set the data source credential

```sh
scripts/set-grafana-gcp-credentials.sh
```

Confirm it authenticates: **Connections → Data sources → GCP Cloud Monitoring →
Save & test**.

## Validate the metric and alert

Generate a synthetic Data Access event as yourself:

```sh
gcloud secrets versions access latest \
  --secret=grafana-gcp-reader-key --project=alunduil >/dev/null
```

Within a few minutes **Alerting → Alert rules → GCP Observability → Unexpected
Data Access** fires, with `principal` set to your account. It stays firing for
ten minutes after the event, then resolves.

An anonymous request is denied and reads nothing, so it must not fire:

```sh
curl -s https://storage.googleapis.com/storage/v1/b/blog.alunduil.com/o >/dev/null
```
