<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Connect Grafana Cloud to GCP metrics and audit logs

Terraform creates the Cloud Monitoring data source, the Data Access
log-based metric, and the audit alert. The one step it can't do is inject the
read-only service-account key: `grafana_data_source` would persist it in the
bucket-readable alunduil state, so the key is set through the Grafana API
instead. Run this after each apply that (re)creates the data source, and on key
rotation.

## Prerequisites

- `just bootstrap` and `terraform/alunduil` both applied.
- `gcloud`, `jq`, and `curl` available, authenticated as an identity that can
  read the `grafana-gcp-reader-key` and `grafana-provisioner-token` secrets.

## Set the data source credential

```sh
scripts/set-grafana-gcp-credentials.sh
```

Confirm it authenticates: **Connections → Data sources → GCP Cloud Monitoring →
Save & test**.

## Validate the alert

Generate a synthetic Data Access event and confirm the alert reacts:

```sh
gcloud secrets versions access latest \
  --secret=grafana-provisioner-token --project=alunduil >/dev/null
```

Within a minute the `audit-data-access` metric increments and the "Data Access
audit events" rule transitions to firing.
