<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Telemetry labels

Defines the labels that trace a metric series or log stream to a machine,
a shipper and a configuration. Written for the operator querying Grafana
Cloud or adding a pipeline.

## Scope

Covers pipelines Fleet Management serves from `terraform/alunduil/`. The
configurations held on TrueNAS, Home Assistant and `penguin` set their own
labels, so a query on these three labels can miss their data.

## Labels

`host`
: Which machine does the data describe? A name from [Hosts](#hosts).
  Corresponds to OpenTelemetry's `host.name`.

`collector_id`
: Which shipper delivered it? The Fleet Management collector ID.

`pipeline`
: Which configuration produced it? The Fleet Management pipeline name.

A pipeline's name is also its template's name: `node_metrics` is
`terraform/alunduil/node_metrics.alloy.tftpl`.

## Hosts

- `deco`
- `homeassistant`
- `nanopi-neo3`
- `penguin`
- `printer`
- `slzb-mr4u`
- `truenas`

## Rules

- Each value is constant for a pipeline and target, so the labels multiply
  no series.
- `host` names the machine described, not the relay. The router's log
  reaches Grafana through Home Assistant, so it takes `host="deco"` and the
  collector ID of Home Assistant's collector.
- `job` and `instance` identify the scrape target. Alerts and dashboards
  query them, so a pipeline keeps setting them.
- Add another label only when `host`, `collector_id`, `pipeline`, `job` and
  `instance` can't answer the question. `pipeline` already implies the
  concern. The estate has one site and one environment, so neither has a
  label.
- Adaptive Metrics aggregation rules must keep all three labels.

## Set the labels in a template

Every `loki.write` and `prometheus.remote_write` component sets them in
`external_labels`, which applies them to everything the pipeline ships:

```alloy
external_labels = {
    "host"         = string.to_lower(constants.hostname),
    "collector_id" = argument.attributes.value["collector.ID"],
    "pipeline"     = "${pipeline}",
}
```

- `constants.hostname` is the machine Alloy runs on. In a container it's the
  container ID, so a containerized collector's template names the host
  literally.
- A label set on a target or stream wins over `external_labels`. A pipeline
  relaying another machine's data sets `host` there.

`scripts/alloy-labels.bats` fails when a template's writer omits a label, or
sets `collector_id` or `pipeline` to anything else. It doesn't check `host`
against the list of [hosts](#hosts).
