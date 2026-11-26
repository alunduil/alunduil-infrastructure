# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Enforces docs/reference/telemetry-labels.md. Alloy accepts a writer without
# external_labels, so neither plan nor apply catches an omission.
#
# Prints `<writer> <label>` for each absent or wrong label, and `no writer` for a
# template that neither defines a writer nor embeds a shared one. Parses by
# indentation, so the template must follow `alloy fmt`.

function report_violations(    i) {
  for (i = 1; i in required; i++) {
    if (!(required[i] in valid)) { print writer, required[i]; failed = 1 }
  }
}

function accepts_any_value(label) { return !(label in expected) }

function label_in(line,    quoted) { split(line, quoted, "\""); return quoted[2] }

function expression_in(line) { sub(/^[^=]*=[ \t]*/, "", line); return line }

BEGIN {
  split("host collector_id pipeline", required, " ")
  expected["collector_id"] = "argument.attributes.value[\"collector.ID\"]"
  expected["pipeline"] = "\"${pipeline}\""
}

/^\$\{(loki_write|prometheus_remote_write)\}$/ { found_writer = 1 }

/^(loki\.write|prometheus\.remote_write) / {
  writer = $1; found_writer = 1; delete valid
}
writer && /^\texternal_labels[ \t]*=[ \t]*\{/ { in_labels = 1; next }
/^\t\}/ { in_labels = 0 }
in_labels && /^\t\t"[^"]+"[ \t]*=/ {
  label = label_in($0)
  if (accepts_any_value(label) || expression_in($0) == expected[label] ",") {
    valid[label] = 1
  }
}
writer && /^\}/ { report_violations(); writer = ""; in_labels = 0 }

END {
  if (!found_writer) { print "no writer"; failed = 1 }
  exit failed
}
