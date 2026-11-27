<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Set the alloy push credential on the collector

Fleet Management sends a collector the text of its pipelines and lets the
collector evaluate them, so the credential a pipeline pushes with can never
travel inside one. Terraform creates a token per collector and stores it in
Secret Manager. You put it on the collector by hand, under the name
`GCLOUD_RW_API_KEY`. Grafana's generated `self_monitoring_*` pipelines have that
name hardcoded, so no other name works.

Run this when a collector is first enrolled and after a bootstrap re-run
rotates the token.

## Prerequisites

- `just bootstrap` applied, so the collector's secret holds a version.
- `gcloud` available, authenticated as an identity that can read that
  secret. The deployer service accounts can't read it.

## Read the token

Replace `<secret>` with the collector's secret:

- TrueNAS: `grafana-alloy-push-token`
- NanoPi-NEO3: `grafana-alloy-push-token-nanopi-neo3`
- Home Assistant: `grafana-alloy-push-token-homeassistant`

```sh
gcloud secrets versions access latest \
  --secret=<secret> --project=alunduil
```

## Set it on the collector

For alloy running as a TrueNAS app on A-01, add it under **Apps → alloy →
Edit → Environment Variables** as `GCLOUD_RW_API_KEY`, then save. TrueNAS
recreates the container, which is the restart alloy needs.

For the NanoPi-NEO3, skip reading the token and run the playbook, which
delivers it:

```sh
just nanopi-neo3
```

See [configure-the-nanopi-neo3.md](configure-the-nanopi-neo3.md) for the
prerequisites.

For the alloy add-on on A-02, which isn't enrolled in Fleet Management, open
**Settings → Add-ons → alloy → Configuration**. Replace the password in
`loki_url` and the Prometheus remote-write password in the YAML
configuration with the token, then save and restart the add-on. Confirm with
`{hostname="homeassistant"}` logs and `up{job="home-assistant"}` instead of
`alloy_build_info`.

## Confirm it worked

```sh
gcx metrics query 'alloy_build_info'
```

The self-monitoring pipelines emit that metric, so a result with a `version`
label confirms both that the credential authenticates and that the collector is
applying remote configuration. An empty result after a few minutes means the
pipelines are still failing to push—check the token scopes in the Cloud Portal
before suspecting the collector.
