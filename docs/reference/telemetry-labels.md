<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Telemetry labels

Every metric series and log stream from a Fleet Management pipeline in
`terraform/alunduil/` must carry these labels. CI checks each template for them.

`host`
: The machine that the data describes: its host name in lower case, or the
  device's name if it has none. Relayed data takes the `host` of the machine
  that it came from. Corresponds to OpenTelemetry's `host.name`.

`collector_id`
: The Fleet Management ID of the collector that shipped the data.

`pipeline`
: The Fleet Management pipeline's name, which is also its template's name.

## Constraints

- Each of these labels has one value for a pipeline and source.
- This contract gains a label only for a question that these three can't
  answer.
- Adaptive Metrics aggregation rules keep all three.
- `job` and `instance` are outside this contract. Existing queries use them,
  so a pipeline that sets them keeps them.
