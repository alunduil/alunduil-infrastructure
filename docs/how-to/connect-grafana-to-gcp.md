<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Connect Grafana Cloud to GCP metrics and audit logs

Terraform creates the data source and the log-based metric. It can't set the
data source's service-account key: that would persist the key in bucket-readable
state, so you set it through the Grafana API instead. Run this when the data
source is first created, when a UID or type change recreates it, and on key
rotation; routine applies leave the key untouched.

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

## Validate the metric

Generate a synthetic Data Access event and confirm it reaches Grafana:

```sh
gcloud secrets versions access latest \
  --secret=grafana-gcp-reader-key --project=alunduil >/dev/null
```

Within a minute the `audit-data-access` metric increments — query
`logging.googleapis.com/user/audit-data-access` against the GCP Cloud
Monitoring data source in Explore to confirm.
