# Shared configuration and helpers for the benchmarking scripts.
# Sourced, not executed: every script does `source "$(dirname "$0")/lib.sh"`.

# --- Tunables (override via environment) ------------------------------------
: "${BACKEND:=gengodb}"              # benchmark target: gengodb | fuseki
: "${SCALE:=sf1000}"                 # label for this dataset/db, e.g. sf1000
: "${PRODUCT_COUNT:=1000}"           # BSBM -pc, drives dataset size
: "${GENGODB_PORT:=8890}"
: "${GENGODB_SPARQL_PATH:=/sparql}"  # ASSUMPTION - see BENCHMARKING.md
: "${FUSEKI_PORT:=3030}"
: "${FUSEKI_DATASET:=ds}"            # Fuseki dataset path segment, e.g. /ds/sparql
: "${RUNS:=20}"                      # BSBM -runs (upstream default: 500)
: "${WARMUPS:=5}"                    # BSBM -w      (upstream default: 50)
: "${SEED:=808080}"                  # BSBM -seed   (upstream default)
: "${DB_CAPACITY:=2000000}"          # gengodb://sparql/settings/#capacity - see
                                      # hosts/GengoDB/known-issues/README.md #2.
                                      # Default GengoDB cap is 1024
                                      # nodes/rels/props, which segfaults on any
                                      # real BSBM dataset; must be raised before
                                      # LOAD-ing. Unused when BACKEND=fuseki.

# --- Paths --------------------------------------------------------------
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"
DATA_DIR="$ROOT_DIR/data"
RESULTS_DIR="$ROOT_DIR/results"

DATASET_DIR_HOST="$DATA_DIR/datasets/$SCALE"
DATASET_DIR_CT="/data/datasets/$SCALE"

GENGODB_DB_DIR_HOST="$DATA_DIR/db/$SCALE"
GENGODB_DB_DIR_CT="/data/db/$SCALE"
FUSEKI_DB_DIR_HOST="$DATA_DIR/db/$SCALE-fuseki"
FUSEKI_DB_DIR_CT="/data/db/$SCALE-fuseki"

log() {
  echo "[$(date -u +%H:%M:%S)] $*" >&2
}

fail() {
  log "ERROR: $*"
  exit 1
}

# --- Backend dispatch -----------------------------------------------------
case "$BACKEND" in
  gengodb)
    BACKEND_SERVICE="gengodb"
    BACKEND_PORT="$GENGODB_PORT"
    BACKEND_SPARQL_PATH="$GENGODB_SPARQL_PATH"
    DB_DIR_HOST="$GENGODB_DB_DIR_HOST"
    DB_DIR_CT="$GENGODB_DB_DIR_CT"
    ;;
  fuseki)
    BACKEND_SERVICE="jena-fuseki"
    BACKEND_PORT="$FUSEKI_PORT"
    BACKEND_SPARQL_PATH="/$FUSEKI_DATASET/sparql"
    DB_DIR_HOST="$FUSEKI_DB_DIR_HOST"
    DB_DIR_CT="$FUSEKI_DB_DIR_CT"
    ;;
  *)
    fail "Unknown BACKEND '$BACKEND' (expected 'gengodb' or 'fuseki')"
    ;;
esac

DB_DIR_CT_SLASH="$DB_DIR_CT/"
export DB_DIR="$GENGODB_DB_DIR_CT/"
export FUSEKI_DB_DIR="$FUSEKI_DB_DIR_CT"
export GENGODB_PORT
export FUSEKI_PORT
export FUSEKI_DATASET

cd "$ROOT_DIR"
