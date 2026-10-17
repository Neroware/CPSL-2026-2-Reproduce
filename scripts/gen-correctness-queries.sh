#!/usr/bin/env bash
# Generate concrete BSBM "explore" query instances (and the reference
# answers to them) for the correctness check, by running the test driver in
# qualification mode against a running Fuseki. The driver logs every query
# string plus its result to run.log (see tools/test-driver/log4j.xml),
# which check-correctness.py then replays against both endpoints.
#
# Uses the explore-all query mix: the same queries as "explore", but with an
# empty ignoreQueries.txt, so queries 6/9/12 are included too.
#
# Usage: ./scripts/gen-correctness-queries.sh <output dir under ./results>
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

OUT_HOST="${1:?usage: gen-correctness-queries.sh <output dir under $RESULTS_DIR>}"
mkdir -p "$OUT_HOST"
OUT_HOST="$(cd "$OUT_HOST" && pwd)"
case "$OUT_HOST" in
  "$RESULTS_DIR"/*) ;;
  *) fail "$OUT_HOST is not under $RESULTS_DIR (the only directory mounted into bsbm-tools)" ;;
esac
OUT_CT="/results/${OUT_HOST#"$RESULTS_DIR"/}"

ENDPOINT="http://jena-fuseki:${FUSEKI_PORT}/${FUSEKI_DATASET}/sparql"

log "Generating $CHECK_RUNS query mix(es) of instances against $ENDPOINT (scale=$SCALE seed=$SEED)"

docker compose run --rm bsbm-tools bash -c "
  ./testdriver -q \
    -qf '$OUT_CT/reference.qual' \
    -runs '$CHECK_RUNS' \
    -seed '$SEED' \
    -idir '$DATASET_DIR_CT' \
    -ucf usecases/explore-all/sparql.txt \
    '$ENDPOINT' && cp run.log '$OUT_CT/run.log'
" 2>&1 | tee "$OUT_HOST/driver.log"

[ -s "$OUT_HOST/run.log" ] || fail "Test driver produced no run.log - see $OUT_HOST/driver.log"

cat > "$OUT_HOST/meta.json" <<EOF
{
  "scale": "$SCALE",
  "product_count": $PRODUCT_COUNT,
  "seed": $SEED,
  "runs": $CHECK_RUNS,
  "query_mix": "explore-all",
  "reference_endpoint": "$ENDPOINT",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

log "Query instances stored in $OUT_HOST/run.log"
