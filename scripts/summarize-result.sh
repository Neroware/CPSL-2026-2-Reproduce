#!/usr/bin/env bash
# Pull the headline numbers *and* the per-query breakdown out of a BSBM
# result.xml. The per-query <queries><query nr="N">...</query></queries>
# block is always present (TestDriver hardcodes printXMLResults(true)), so
# this doesn't need any special driver flag to work.
set -euo pipefail
FILE="${1:?usage: summarize-result.sh <result.xml>}"

extract() {
  # $1 = xml tag, prints its text content (first match) or "n/a"
  grep -o "<$1>[^<]*</$1>" "$FILE" | head -1 | sed -E "s#</?$1>##g" || true
}

SF=$(extract scalefactor); SF=${SF:-n/a}
RUNS=$(extract querymixruns); RUNS=${RUNS:-n/a}
QMPH=$(extract qmph); QMPH=${QMPH:-n/a}
CQET=$(extract cqet); CQET=${CQET:-n/a}
CQETG=$(extract cqetg); CQETG=${CQETG:-n/a}
TOTAL=$(extract totalruntime); TOTAL=${TOTAL:-n/a}

cat <<EOF
== BSBM result summary ($FILE) ==
Scale factor (product count):      $SF
Query mix runs (measured):         $RUNS
Total runtime (s):                 $TOTAL
Query Mixes per Hour (QMpH):       $QMPH
Avg. query mix runtime (s, arith): $CQET
Avg. query mix runtime (s, geom):  $CQETG

Per-query breakdown:
EOF

awk '
  BEGIN {
    printf "%-4s %-6s %-12s %-12s %-10s %-10s %-8s\n", "nr", "count", "aqet(s)", "aqetg(s)", "qps", "avgres", "timeouts"
  }
  /<query nr="/ {
    line = $0
    sub(/^[^"]*"/, "", line); sub(/".*$/, "", line)
    nr = line
    count = aqet = aqetg = qps = avgres = timeouts = "-"
  }
  /<executecount>/ { gsub(/<\/?executecount>/, ""); gsub(/^[ \t]+/, ""); count = $0 }
  /<aqet>/          { gsub(/<\/?aqet>/, "");          gsub(/^[ \t]+/, ""); aqet = $0 }
  /<aqetg>/         { gsub(/<\/?aqetg>/, "");         gsub(/^[ \t]+/, ""); aqetg = $0 }
  /<qps>/           { gsub(/<\/?qps>/, "");           gsub(/^[ \t]+/, ""); qps = $0 }
  /<avgresults>/    { gsub(/<\/?avgresults>/, "");    gsub(/^[ \t]+/, ""); avgres = $0 }
  /<timeoutcount>/  { gsub(/<\/?timeoutcount>/, ""); gsub(/^[ \t]+/, ""); timeouts = $0 }
  /<\/query>/ {
    printf "%-4s %-6s %-12s %-12s %-10s %-10s %-8s\n", nr, count, aqet, aqetg, qps, avgres, timeouts
  }
' "$FILE"
