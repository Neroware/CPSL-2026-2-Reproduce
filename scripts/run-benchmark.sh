#!/usr/bin/env bash
# Run the BSBM "explore" query mix against a running $BACKEND server and
# store results under ./results/<run-id>/.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

[ -f "$DB_DIR_HOST/.initialized" ] || fail "DB directory not initialized at $DB_DIR_HOST - run init-db.sh first"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-${SCALE}-${BACKEND}"
RUN_DIR="$RESULTS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR"

ENDPOINT="http://${BACKEND_SERVICE}:${BACKEND_PORT}${BACKEND_SPARQL_PATH}"

log "Running BSBM 'explore' query mix against $ENDPOINT"
log "backend=$BACKEND scale=$SCALE runs=$RUNS warmups=$WARMUPS seed=$SEED"

docker compose run --rm bsbm-tools \
  ./testdriver \
    -runs "$RUNS" \
    -w "$WARMUPS" \
    -seed "$SEED" \
    -idir "$DATASET_DIR_CT" \
    -ucf usecases/explore/sparql.txt \
    -o "/results/$RUN_ID/result.xml" \
    "$ENDPOINT" \
  2>&1 | tee "$RUN_DIR/driver.log"

cat > "$RUN_DIR/meta.json" <<EOF
{
  "run_id": "$RUN_ID",
  "backend": "$BACKEND",
  "scale": "$SCALE",
  "product_count": $PRODUCT_COUNT,
  "runs": $RUNS,
  "warmups": $WARMUPS,
  "seed": $SEED,
  "query_mix": "explore",
  "endpoint": "$ENDPOINT",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

"$SCRIPT_DIR/summarize-result.sh" "$RUN_DIR/result.xml" | tee "$RUN_DIR/summary.txt"

log "Results stored in $RUN_DIR"
