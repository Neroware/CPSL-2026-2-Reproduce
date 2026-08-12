#!/usr/bin/env bash
# Secondary, lightweight benchmarking routine for hand-crafted GengoDB
# SPARQL/MLIR modules, separate from the full BSBM routine
# (benchmark.sh/run-benchmark.sh). Runs GengoDB's own `run-sparql`/
# `run-mlir` CLI tools directly against an already-initialized DB
# directory (no HTTP endpoint involved), some number of times per file,
# and writes the timing breakdown they print (see
# lingodb::execution::TimingPrinter) to a result table under
# results/custom/.
#
# GengoDB-only: run-sparql/run-mlir don't exist in the Fuseki image, and
# these operate directly on a DB directory rather than through an
# endpoint - BACKEND is forced to gengodb regardless of the environment.
#
# Usage:
#   ./scripts/run-custom.sh [--reps N] [--warmups N] <file...>
#   ./scripts/run-custom.sh [--reps N] [--warmups N] --all
#
# Files must live under queries/custom/{sparql,mlir}/ - see
# queries/custom/README.md - since that's the only host directory
# bind-mounted into the gengodb container for this purpose (as /queries,
# see docker-compose.yml). --all runs everything found there.
#
# Configure via the same SCALE env var as the rest of scripts/ (selects
# which initialized DB directory, ./data/db/$SCALE, to run against).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ "${BACKEND:-gengodb}" != "gengodb" ]; then
  echo "[run-custom.sh] Note: BACKEND=$BACKEND ignored - this routine is GengoDB-only (run-sparql/run-mlir have no Fuseki equivalent)." >&2
fi
export BACKEND=gengodb
source ./lib.sh

COLUMNS=(QOpt lowerRelAlg lowerSubOp lowerDB lowerArrow lowerToLLVM baselineLowering toLLVMIR llvmOptimize llvmCodeGen baselineCodeGen baselineEmit executionTime total)

QUERIES_DIR="$ROOT_DIR/queries/custom"
REPS=5
WARMUPS=1
ALL=0
FILES=()

print_help() {
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --reps) REPS="$2"; shift 2 ;;
    --warmups) WARMUPS="$2"; shift 2 ;;
    --all) ALL=1; shift ;;
    -h|--help) print_help; exit 0 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

[ -f "$GENGODB_DB_DIR_HOST/.initialized" ] || fail "GengoDB DB directory not initialized at $GENGODB_DB_DIR_HOST - run init-db.sh first"

if [ "$ALL" = "1" ]; then
  shopt -s nullglob
  FILES=("$QUERIES_DIR"/sparql/*.sparql "$QUERIES_DIR"/sparql/*.rq "$QUERIES_DIR"/mlir/*.mlir)
  shopt -u nullglob
fi

[ "${#FILES[@]}" -gt 0 ] || fail "No files given - pass one or more file paths, or --all to run everything under $QUERIES_DIR (see queries/custom/README.md)"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-${SCALE}-custom"
RUN_DIR="$RESULTS_DIR/custom/$RUN_ID"
LOG_DIR="$RUN_DIR/logs"
mkdir -p "$LOG_DIR"
CSV="$RUN_DIR/results.csv"

{
  printf 'file,type,warmups,reps_requested,reps_ok,status'
  for c in "${COLUMNS[@]}"; do printf ',%s_mean' "$c"; done
  printf ',executionTime_min,executionTime_max,total_min,total_max\n'
} > "$CSV"

log "Custom module run $RUN_ID: ${#FILES[@]} file(s), $WARMUPS warmup(s) + $REPS measured rep(s) each"

for file in "${FILES[@]}"; do
  [ -f "$file" ] || fail "File not found: $file"

  base="$(basename "$file")"
  ext="${base##*.}"
  case "$ext" in
    sparql|rq) BIN=run-sparql ;;
    mlir) BIN=run-mlir ;;
    *) log "Skipping $file: unknown extension .$ext (expected .sparql, .rq or .mlir)"; continue ;;
  esac

  realfile="$(cd "$(dirname "$file")" && pwd)/$base"
  case "$realfile" in
    "$QUERIES_DIR"/*) ;;
    *) fail "$file is not under $QUERIES_DIR - copy/move it there first (see queries/custom/README.md)" ;;
  esac
  container_file="/queries/${realfile#"$QUERIES_DIR"/}"

  log "-- $base ($BIN) --"

  for w in $(seq 1 "$WARMUPS"); do
    docker compose run --rm gengodb "/gengodb/build/lingodb-release/$BIN" "$container_file" "$DB_DIR_CT_SLASH" \
      >/dev/null 2>&1 || log "   warmup $w/$WARMUPS failed (continuing)"
  done

  REP_ROWS=()
  REPS_OK=0
  for r in $(seq 1 "$REPS"); do
    replog="$LOG_DIR/${base}.rep${r}.log"
    set +e
    docker compose run --rm gengodb "/gengodb/build/lingodb-release/$BIN" "$container_file" "$DB_DIR_CT_SLASH" \
      > "$replog" 2>&1
    status=$?
    set -e
    if [ "$status" -ne 0 ]; then
      log "   rep $r/$REPS FAILED (exit $status) - see $replog"
      continue
    fi
    if row="$("$SCRIPT_DIR/parse-timing.sh" "$replog")"; then
      REP_ROWS+=("$row")
      REPS_OK=$((REPS_OK + 1))
    else
      log "   rep $r/$REPS: no timing table in output - see $replog"
    fi
  done

  if [ "$REPS_OK" -eq 0 ]; then
    log "   0/$REPS reps succeeded"
    empties=""
    for _ in $(seq 1 "$((${#COLUMNS[@]} + 4))"); do empties="${empties},"; done
    printf '%s,%s,%s,%s,%s,FAILED%s\n' "$base" "$ext" "$WARMUPS" "$REPS" 0 "$empties" >> "$CSV"
    continue
  fi

  log "   $REPS_OK/$REPS reps succeeded"
  AGG="$(printf '%s\n' "${REP_ROWS[@]}" | awk -F, -v ncols="${#COLUMNS[@]}" '
    {
      for (i = 1; i <= ncols; i++) {
        v = $i
        if (v != "") {
          sum[i] += v; cnt[i]++
          if (!(i in mn) || v < mn[i]) mn[i] = v
          if (!(i in mx) || v > mx[i]) mx[i] = v
        }
      }
    }
    END {
      out = ""
      for (i = 1; i <= ncols; i++) out = out (i == 1 ? "" : ",") (cnt[i] > 0 ? sum[i] / cnt[i] : "")
      et = ncols - 1; tot = ncols
      out = out "," (et in mn ? mn[et] : "") "," (et in mx ? mx[et] : "")
      out = out "," (tot in mn ? mn[tot] : "") "," (tot in mx ? mx[tot] : "")
      print out
    }
  ')"
  echo "$base,$ext,$WARMUPS,$REPS,$REPS_OK,OK,$AGG" >> "$CSV"
done

{
  echo "== Custom module timing summary ($RUN_ID) =="
  echo "(all times in ms - see lingodb::execution::TimingPrinter; mean over successful reps, blank = phase not used)"
  echo
  if command -v column >/dev/null 2>&1; then
    column -t -s, "$CSV"
  else
    cat "$CSV"
  fi
} | tee "$RUN_DIR/results.txt"

cat > "$RUN_DIR/meta.json" <<EOF
{
  "run_id": "$RUN_ID",
  "scale": "$SCALE",
  "db_dir": "$GENGODB_DB_DIR_HOST",
  "warmups": $WARMUPS,
  "reps": $REPS,
  "files": [$(printf '"%s",' "${FILES[@]}" | sed 's/,$//')],
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

log "Results stored in $RUN_DIR"
