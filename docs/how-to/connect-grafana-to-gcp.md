<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Connect Grafana Cloud to GCP metrics and audit logs

Terraform creates the data source and the log-based metric but can't set the
data source's service-account key without persisting it in bucket-readable
state — so you set the key through the Grafana API. Run this when the data
source is first created or recreated (initial rollout, or a rare UID or type
change), and on key rotation; routine applies leave the key untouched.

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

## Validate the metric

Generate a synthetic Data Access event and confirm it reaches Grafana:

```sh
gcloud secrets versions access latest \
  --secret=grafana-provisioner-token --project=alunduil >/dev/null
```

Within a minute the `audit-data-access` metric increments — query
`logging.googleapis.com/user/audit-data-access` against the GCP Cloud
Monitoring data source in Explore to confirm.
