# shellcheck shell=bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Checks the labels docs/reference/telemetry-labels.md requires. Alloy accepts a
# writer without external_labels, so an omission never fails a plan or an apply.

# Prints each label a template's writers leave out, as `<writer> <label>`.
# Relies on `alloy fmt` style: a top-level component closes in column one.
missing_labels() {
  awk '
    function report_missing(    i) {
      for (i = 1; i <= count; i++) {
        if (!(required[i] in set)) { print writer, required[i]; failed = 1 }
      }
    }
    BEGIN {
      count = split("host collector_id pipeline", required, " ")
      # A required label without an entry takes any expression.
      expected["collector_id"] = "argument.attributes.value[\"collector.ID\"]"
      expected["pipeline"] = "\"${pipeline}\""
    }
    /^(loki\.write|prometheus\.remote_write) / {
      writer = $1; writers++; delete set
    }
    writer && /^\texternal_labels[ \t]*=[ \t]*\{/ { in_labels = 1; next }
    /^\t\}/ { in_labels = 0 }
    in_labels && /^\t\t"[^"]+"[ \t]*=/ {
      split($0, quoted, "\""); label = quoted[2]
      expression = $0; sub(/^[^=]*=[ \t]*/, "", expression)
      if (!(label in expected) || expression == expected[label] ",") {
        set[label] = 1
      }
    }
    writer && /^\}/ { report_missing(); writer = ""; in_labels = 0 }
    END {
      if (!writers) { print "no writer"; failed = 1 }
      exit failed
    }
  ' "$1"
}
