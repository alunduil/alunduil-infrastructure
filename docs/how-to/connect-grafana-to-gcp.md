<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Connect Grafana Cloud to GCP metrics and audit logs

Grafana Cloud queries GCP directly at dashboard and alert time through a
read-only service account — no logs or metrics are ingested. The Cloud
Monitoring data source surfaces metrics, and a log-based metric over the
Data Access audit logs powers audit alerting (the Cloud Logging query
language has no Grafana alerting support, so alerts ride the counter).

## Prerequisites

- `just bootstrap` applied — creates the `grafana-gcp-reader` service
  account, its key, and the `grafana-gcp-reader-key` Secret Manager
  secret.
- `terraform/alunduil` applied — creates the `gcp-cloud-monitoring` data
  source and the `audit-data-access` log-based metric.
- `gcloud`, `jq`, and `curl` available, authenticated as an identity that
  can read the two secrets (project owner).

## Set the data source credential

The service-account key is set through the Grafana API rather than
Terraform so it never enters the alunduil state:

```sh
scripts/set-grafana-gcp-credentials.sh
```

Confirm the data source authenticates: in Grafana, **Connections → Data
sources → GCP Cloud Monitoring → Save & test**.

## Create the audit alert

1. **Alerting → Alert rules → New alert rule.**
2. Query the **GCP Cloud Monitoring** data source for the metric
   `logging.googleapis.com/user/audit-data-access`, aligned as a rate.
3. Set the condition to fire when the count is above `0` over the
   evaluation window, and attach your notification policy.

## Validate

Generate a synthetic Data Access event and confirm it lands:

```sh
gcloud secrets versions access latest \
  --secret=grafana-provisioner-token --project=alunduil >/dev/null
```

Within a minute the `audit-data-access` metric increments in the Cloud
Monitoring data source and the alert transitions to firing. The event
still lands in Cloud Logging's `_Default`/`_Required` buckets — the data
source reads, it does not divert.
