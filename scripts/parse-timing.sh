#!/usr/bin/env bash
# Extract the per-run timing breakdown that run-sparql/run-mlir print at the
# end of a successful invocation into a single CSV line (see GengoDB's
# lingodb::execution::TimingPrinter::process(),
# include/lingodb/execution/Timing.h). Used by run-custom.sh.
#
# That table is fixed-width and right-justified, and columns for
# phases the active execution mode doesn't use are printed blank (e.g.
# baselineLowering/baselineCodeGen/baselineEmit when the baseline backend is
# off, which is the default - see hosts/GengoDB/Dockerfile's
# ENABLE_BASELINE_BACKEND). Naive whitespace-splitting silently misaligns
# columns whenever that happens, so this locates column boundaries
# positionally instead:
#   - the header line is the one ending in "...executionTime   total"
#   - the "name" field's width is however many characters "name" itself is
#     right-justified into (leading spaces + 4)
#   - every remaining column shares one width: (header length - name width)
#     / 14 (14 = the number of columns TimingPrinter currently prints -
#     printOrder in Timing.h; update NCOLS below if that list's length
#     changes)
#
# Usage:
#   parse-timing.sh <log file>   -> one CSV line of 14 values, in
#                                    TimingPrinter's printOrder (see
#                                    run-custom.sh's COLUMNS array for names)
# Exits 1 (no output) if the log has no timing table, e.g. because the run
# crashed or errored before printing one.
set -euo pipefail

FILE="${1:?usage: parse-timing.sh <run-sparql|run-mlir log file>}"
NCOLS=14

awk -v ncols="$NCOLS" '
  /executionTime[ \t]+total$/ { header = $0; getline data; found = 1; exit }
  END {
    if (!found) { exit 1 }
    match(header, /^ *name/); namelen = RLENGTH
    collen = (length(header) - namelen) / ncols
    if (collen != int(collen) || collen <= 0) {
      print "parse-timing.sh: could not determine column width (header=[" header "])" > "/dev/stderr"
      exit 1
    }
    out = ""
    for (i = 0; i < ncols; i++) {
      start = namelen + i * collen + 1
      field = substr(data, start, collen)
      gsub(/^[ \t]+|[ \t]+$/, "", field)
      out = out (i == 0 ? "" : ",") field
    }
    print out
  }
' "$FILE"
