<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Telemetry labels

Every metric series and log stream from a Fleet Management pipeline in
`terraform/alunduil/` must carry these labels. CI checks each template for
`host`, `collector_id` and `pipeline`.

`host`
: The machine that the data describes: its host name in lower case, or the
  device's name if it has none. Relayed data takes the `host` of the machine
  that it came from. Corresponds to OpenTelemetry's `host.name`.

`collector_id`
: The Fleet Management ID of the collector that shipped the data.

`pipeline`
: The Fleet Management pipeline's name, which is also its template's name.

`job` and `instance`
: The scrape target's identity.

## Constraints

- A label's value is constant for a pipeline and target.
- Another label is allowed only for a question that these five can't answer.
- Adaptive Metrics aggregation rules keep `host`, `collector_id` and
  `pipeline`.
