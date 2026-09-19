<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Set the alloy push credential on the collector

Fleet Management sends a collector the text of its pipelines and lets the
collector evaluate them, so the credential a pipeline pushes with can never
travel inside one. Terraform creates the token (C-22) and stores it in Secret
Manager; you put it on the collector by hand, under the name
`GCLOUD_RW_API_KEY`. Grafana's generated `self_monitoring_*` pipelines have that
name hardcoded, so nothing else works.

Run this when a collector is first enrolled and after a bootstrap re-run
rotates the token.

## Prerequisites

- `just bootstrap` applied, so the secret holds a version.
- `gcloud` available, authenticated as an identity that can read the
  `grafana-alloy-push-token` secret. Neither deployer service account can —
  the binding is deliberately absent.

## Read the token

```sh
gcloud secrets versions access latest \
  --secret=grafana-alloy-push-token --project=alunduil
```

## Set it on the collector

For alloy running as a TrueNAS app on A-01, add it under **Apps → alloy →
Edit → Environment Variables** as `GCLOUD_RW_API_KEY`, then save. TrueNAS
recreates the container, which is the restart alloy needs.

## Confirm it worked

Alloy reports its own version to Fleet Management as the `collector.version`
attribute, but that attribute reaches only the Fleet Management collector page.
The self-monitoring pipelines are what put it in Prometheus, and they're also
the first thing to recover once the credential's in place:

```sh
gcx metrics query 'alloy_build_info'
```

A result with a `version` label confirms both that the credential authenticates
and that the collector is applying remote configuration. An empty result within
a few minutes means the pipelines are still failing to push — check the token
scopes in the Cloud Portal before suspecting the collector.
