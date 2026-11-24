<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Telemetry labels

Three labels trace a metric series or log stream to a machine, a collector
and a configuration.

## Scope

Applies to the Fleet Management pipelines in `terraform/alunduil/`. Assumes
knowledge of Alloy.

Out of scope: TrueNAS, Home Assistant and `penguin`, whose telemetry
configuration isn't in Terraform. A query on these labels can miss their
data.

## Labels

`host`
: The machine that the data describes, as one of the [hosts](#hosts).
  Equivalent to OpenTelemetry's `host.name`.

`collector_id`
: The Fleet Management ID of the collector that shipped the data.

`pipeline`
: The name of the Fleet Management pipeline that produced the data. The
  template has the same name: `node_metrics` comes from
  `node_metrics.alloy.tftpl`.

## Hosts

- `deco`
- `homeassistant`
- `nanopi-neo3`
- `penguin`
- `printer`
- `slzb-mr4u`
- `truenas`

## Rules

- Each value is constant for a pipeline and target, so the labels don't
  multiply series.
- Relayed data takes the `host` of the machine that it came from. The
  router's log belongs to `deco`, although Home Assistant relays it.
- Alerts and dashboards query `job` and `instance`, which identify the
  scrape target. Every pipeline sets them too.
- Add a label only for a question that `host`, `collector_id`, `pipeline`,
  `job` and `instance` can't answer. The estate has one site and one
  environment, so neither needs a label.
- Adaptive Metrics aggregation rules must keep all three labels.

## Label a new pipeline

Copy the `external_labels` block from `node_metrics.alloy.tftpl` into every
writer.

- In a container, `constants.hostname` is the container ID. Name the host
  literally instead.
- Labels on a target or stream override `external_labels`. For relayed data,
  set `host` there.

CI rejects a template that omits a label, but it accepts any value for
`host`.
