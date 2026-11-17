#!/usr/bin/env bash
# End-to-end BSBM benchmarking routine for GengoDB or Jena Fuseki:
#   build images -> generate dataset -> init db -> serve -> smoke test
#   -> run test driver -> (stop server, unless --keep-server)
#
# Configure via environment variables (see lib.sh for defaults):
#   BACKEND (gengodb|fuseki), SCALE, PRODUCT_COUNT, GENGODB_PORT,
#   GENGODB_SPARQL_PATH, FUSEKI_PORT, FUSEKI_DATASET, RUNS, WARMUPS, SEED
#   CHECK_CORRECTNESS=1 additionally runs run-correctness.sh afterwards
#   (BACKEND=gengodb only; needs the Fuseki DB for $SCALE initialized too).
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
if [ "$BACKEND" = "gengodb" ] && [ -z "${GENGODB_CACHEBUST:-}" ]; then
  GENGODB_REF="$(sed -n 's/^RUN git checkout //p' "$ROOT_DIR/hosts/GengoDB/Dockerfile")"
  GENGODB_CACHEBUST="$(git ls-remote git@github.com:Neroware/GengoDB.git \
    "refs/tags/$GENGODB_REF^{}" "refs/tags/$GENGODB_REF" "refs/heads/$GENGODB_REF" | head -1 | cut -f1)"
  [ -n "$GENGODB_CACHEBUST" ] || fail "Could not resolve GengoDB ref '$GENGODB_REF' on remote"
  export GENGODB_CACHEBUST
  log "GengoDB ref $GENGODB_REF -> $GENGODB_CACHEBUST"
fi
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

if [ "${CHECK_CORRECTNESS:-0}" = "1" ] && [ "$BACKEND" = "gengodb" ]; then
  log "== extra: correctness check against Fuseki =="
  "$SCRIPT_DIR/run-correctness.sh"
fi

log "Done."
