<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Connect Grafana Cloud to GCP metrics and audit logs

Terraform creates both GCP data sources and the log-based metric. It can't set
their service-account key: that would persist the key in bucket-readable state,
so you set it through the Grafana API instead. Run this when a data source is
first created, when a UID or type change recreates it, and on key rotation;
routine applies leave the key untouched.

## Prerequisites

- `just bootstrap` and `terraform/alunduil` both applied.
- `gcloud` and `jq` available, authenticated as an identity that can read the
  `grafana-gcp-reader-key` secret.
- `gcx` logged in to the `alunduil` stack. It carries the Grafana credential, so
  the script needs no API token of its own.

## Set the data source credentials

```sh
scripts/set-grafana-gcp-credentials.sh
```

Pass UIDs to key a subset — `scripts/set-grafana-gcp-credentials.sh
gcp-cloud-logging`.

Confirm each authenticates: **Connections → Data sources → GCP Cloud
Monitoring → Save & test**, then the same for **GCP Cloud Logging**.

## Validate the metric

Generate a synthetic Data Access event and confirm it reaches Grafana:

```sh
gcloud secrets versions access latest \
  --secret=grafana-gcp-reader-key --project=alunduil >/dev/null
```

Within a minute the `audit-data-access` metric increments — query
`logging.googleapis.com/user/audit-data-access` against the GCP Cloud
Monitoring data source in Explore to confirm.

## Read the audit line behind the count

The metric counts entries; the entries themselves stay in Cloud Logging. In
Explore, pick **GCP Cloud Logging** and query:

```text
logName="projects/alunduil/logs/cloudaudit.googleapis.com%2Fdata_access"
```

The read you just generated appears with its caller, method, and resource.
