# shellcheck shell=bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Enforces docs/reference/telemetry-labels.md. Alloy accepts a writer without
# external_labels, so neither plan nor apply catches an omission.

# Prints `<writer> <label>` for each absent or wrong label, or `no writer`.
# Parses by indentation, so the template must follow `alloy fmt`.
label_violations() {
  awk '
    function report_violations(    i) {
      for (i = 1; i <= count; i++) {
        if (!(required[i] in valid)) { print writer, required[i]; failed = 1 }
      }
    }
    function accepts_any_value(label) { return !(label in expected) }
    BEGIN {
      count = split("host collector_id pipeline", required, " ")
      expected["collector_id"] = "argument.attributes.value[\"collector.ID\"]"
      expected["pipeline"] = "\"${pipeline}\""
    }
    /^(loki\.write|prometheus\.remote_write) / {
      writer = $1; writers++; delete valid
    }
    writer && /^\texternal_labels[ \t]*=[ \t]*\{/ { in_labels = 1; next }
    /^\t\}/ { in_labels = 0 }
    in_labels && /^\t\t"[^"]+"[ \t]*=/ {
      split($0, quoted, "\""); label = quoted[2]
      expression = $0; sub(/^[^=]*=[ \t]*/, "", expression)
      if (accepts_any_value(label) || expression == expected[label] ",") {
        valid[label] = 1
      }
    }
    writer && /^\}/ { report_violations(); writer = ""; in_labels = 0 }
    END {
      if (!writers) { print "no writer"; failed = 1 }
      exit failed
    }
  ' "$1"
}
