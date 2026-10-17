#!/usr/bin/env bash
# Correctness check: replay concrete BSBM "explore" query instances against
# GengoDB and compare every answer with Jena Fuseki's (the reference
# implementation). Starts whichever of the two servers isn't already
# running (and stops only those again at the end), generates the query
# instances + reference answers once per scale/seed/runs (reused on later
# runs, FORCE=1 to regenerate), then runs check-correctness.py.
#
# Results land in results/correctness/<run-id>/ (summary.txt, summary.csv,
# instances.jsonl, meta.json); see scripts/check-correctness.py for what
# each status means.
#
# Configure via the usual env vars (SCALE, SEED, ...) plus CHECK_RUNS and
# CHECK_TIMEOUT (see lib.sh). Needs both DB directories initialized:
#   ./scripts/init-db.sh && BACKEND=fuseki ./scripts/init-db.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

[ -f "$GENGODB_DB_DIR_HOST/.initialized" ] || fail "GengoDB DB not initialized at $GENGODB_DB_DIR_HOST - run init-db.sh first"
[ -f "$FUSEKI_DB_DIR_HOST/.initialized" ] || fail "Fuseki DB not initialized at $FUSEKI_DB_DIR_HOST - run BACKEND=fuseki init-db.sh first"

REF_ENDPOINT="http://jena-fuseki:${FUSEKI_PORT}/${FUSEKI_DATASET}/sparql"
TEST_ENDPOINT="http://gengodb:${GENGODB_PORT}${GENGODB_SPARQL_PATH}"

docker compose build bsbm-tools

STARTED=()
cleanup() {
  for b in "${STARTED[@]}"; do
    BACKEND="$b" "$SCRIPT_DIR/serve.sh" stop || true
  done
}
trap cleanup EXIT

for b in fuseki gengodb; do
  svc="$b"; db="$GENGODB_DB_DIR_CT"
  [ "$b" = fuseki ] && { svc=jena-fuseki; db="$FUSEKI_DB_DIR_CT"; }
  cid="$(docker compose ps --status running -q "$svc")"
  if [ -z "$cid" ]; then
    BACKEND="$b" "$SCRIPT_DIR/serve.sh" start
    STARTED+=("$b")
  else
    # Reusing a running server is only valid if it serves this $SCALE.
    case " $(docker inspect -f '{{join .Args " "}}' "$cid") " in
      *[\ =]"$db"[/\ ]*) log "$svc already running on $db - using it as is" ;;
      *) fail "$svc is running, but not on $db - stop it first (BACKEND=$b ./scripts/serve.sh stop)" ;;
    esac
  fi
done

# serve.sh only waits for the port, which Docker's proxy opens before the
# server inside is ready - wait until each endpoint actually answers.
for url in "http://localhost:${FUSEKI_PORT}/${FUSEKI_DATASET}/sparql" \
           "http://localhost:${GENGODB_PORT}${GENGODB_SPARQL_PATH}"; do
  for i in $(seq 1 60); do
    curl -fsS -o /dev/null -G "$url" --data-urlencode 'query=SELECT * WHERE { ?s ?p ?o } LIMIT 1' 2>/dev/null && break
    [ "$i" -eq 60 ] && fail "$url did not answer a SPARQL query within 120s"
    sleep 2
  done
done

REF_DIR="$RESULTS_DIR/correctness/reference/${SCALE}-seed${SEED}-runs${CHECK_RUNS}"
REF_DIR_CT="/results/${REF_DIR#"$RESULTS_DIR"/}"
if [ "${FORCE:-0}" = "1" ]; then
  # Removed from inside the container: everything in there is written as root.
  docker compose run --rm bsbm-tools rm -rf "$REF_DIR_CT"
fi
if [ ! -s "$REF_DIR/run.log" ]; then
  "$SCRIPT_DIR/gen-correctness-queries.sh" "$REF_DIR"
else
  log "Reusing query instances from $REF_DIR"
fi

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-${SCALE}-correctness"
RUN_DIR="$RESULTS_DIR/correctness/$RUN_ID"
mkdir -p "$RUN_DIR"

# Record exactly which GengoDB build and server flags were checked (e.g.
# whether --enable-cache was on), since both change the answers.
GENGODB_CID="$(docker compose ps -q gengodb)"
GENGODB_IMAGE="$(docker inspect -f '{{.Image}}' "$GENGODB_CID" 2>/dev/null || echo unknown)"
GENGODB_ARGS="$(docker inspect -f '{{join .Args " "}}' "$GENGODB_CID" 2>/dev/null || echo unknown)"

log "Checking $TEST_ENDPOINT against $REF_ENDPOINT (scale=$SCALE seed=$SEED runs=$CHECK_RUNS)"

docker compose run --rm bsbm-tools python3 check-correctness.py \
  --queries "$REF_DIR_CT/run.log" \
  --reference "$REF_ENDPOINT" \
  --test "$TEST_ENDPOINT" \
  --out "/results/correctness/$RUN_ID" \
  --ref-cache "$REF_DIR_CT/cache" \
  --timeout "$CHECK_TIMEOUT" \
  --meta "run_id=$RUN_ID" \
  --meta "scale=$SCALE" \
  --meta "seed=$SEED" \
  --meta "check_runs=$CHECK_RUNS" \
  --meta "gengodb_image=$GENGODB_IMAGE" \
  --meta "gengodb_args=$GENGODB_ARGS" \
  --meta "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

log "Results stored in $RUN_DIR"
