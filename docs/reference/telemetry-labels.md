<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Telemetry labels

Every metric series and log stream from a Fleet Management pipeline in
`terraform/alunduil/` must carry these labels. CI checks each template for them.

`host`
: The lower-case hostname of the machine that the data describes, or its device
  name if it has no hostname. Relayed data names the originating machine.
  Corresponds to OpenTelemetry's `host.name`.

`collector_id`
: The Fleet Management ID of the collector that shipped the data.

`pipeline`
: The name of the Fleet Management pipeline. Its template is
  `<pipeline>.alloy.tftpl`.

## Constraints

- Each label has one value per pipeline and source, so it multiplies no series.
- A new required label must answer a question that these three can't.
- Adaptive Metrics aggregation rules must keep all three.
- `job` and `instance` aren't required. A pipeline that sets either must keep
  it, because existing queries use both.
