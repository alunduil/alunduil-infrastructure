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
    /^(loki\.write|prometheus\.remote_write) / {
      writer = $1; writers++; delete seen
    }
    writer && /^\texternal_labels[ \t]*=[ \t]*\{/ { labels = 1 }
    labels && /^\t\t"host"[ \t]*=/ { seen["host"] = 1 }
    labels && /^\t\t"collector_id"[ \t]*=[ \t]*argument\.attributes\.value\["collector\.ID"\],$/ {
      seen["collector_id"] = 1
    }
    labels && /^\t\t"pipeline"[ \t]*=[ \t]*"\$\{pipeline\}",$/ {
      seen["pipeline"] = 1
    }
    labels && /^\t\}/ { labels = 0 }
    writer && /^\}/ {
      n = split("host collector_id pipeline", required, " ")
      for (i = 1; i <= n; i++) {
        if (!(required[i] in seen)) { print writer, required[i]; failed = 1 }
      }
      writer = ""; labels = 0
    }
    END {
      if (!writers) { print "no writer"; failed = 1 }
      exit failed
    }
  ' "$1"
}
