#!/usr/bin/env bash
# End-to-end BSBM benchmarking routine for GengoDB or Jena Fuseki:
#   build images -> generate dataset -> init db -> serve -> smoke test
#   -> run test driver -> (stop server, unless --keep-server)
#
# Configure via environment variables (see lib.sh for defaults):
#   BACKEND (gengodb|fuseki), SCALE, PRODUCT_COUNT, GENGODB_PORT,
#   GENGODB_SPARQL_PATH, FUSEKI_PORT, FUSEKI_DATASET, RUNS, WARMUPS, SEED
# Examples:
#   SCALE=sf5000 PRODUCT_COUNT=5000 RUNS=50 WARMUPS=10 ./scripts/benchmark.sh
#   BACKEND=fuseki ./scripts/benchmark.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

KEEP_SERVER=0
for arg in "$@"; do
  case "$arg" in
    --keep-server) KEEP_SERVER=1 ;;
    --force) export FORCE=1 ;;
    -h|--help)
      echo "Usage: $0 [--keep-server] [--force]"
      exit 0
      ;;
    *) fail "Unknown argument: $arg" ;;
  esac
done

cleanup() {
  if [ "$KEEP_SERVER" != "1" ]; then
    "$SCRIPT_DIR/serve.sh" stop || true
  fi
}
trap cleanup EXIT

log "== 1/6: build images (backend=$BACKEND) =="
docker compose build "$BACKEND_SERVICE" bsbm-tools

log "== 2/6: generate dataset =="
"$SCRIPT_DIR/generate-dataset.sh"

log "== 3/6: initialize database directory =="
"$SCRIPT_DIR/init-db.sh"

log "== 4/6: start server =="
"$SCRIPT_DIR/serve.sh" start

log "== 5/6: smoke test =="
"$SCRIPT_DIR/smoke-test.sh"

log "== 6/6: run benchmark =="
"$SCRIPT_DIR/run-benchmark.sh"

log "Done."
