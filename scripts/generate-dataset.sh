#!/usr/bin/env bash
# Generate a BSBM Turtle dataset (+ test-driver parameter files) at the
# configured SCALE/PRODUCT_COUNT into ./data/datasets/$SCALE.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

if [ -f "$DATASET_DIR_HOST/dataset.ttl" ] && [ "${FORCE:-0}" != "1" ]; then
  log "Dataset already exists at $DATASET_DIR_HOST/dataset.ttl (set FORCE=1 to regenerate)"
  exit 0
fi

mkdir -p "$DATASET_DIR_HOST"

log "Generating BSBM dataset: scale=$SCALE product_count=$PRODUCT_COUNT"
docker compose run --rm bsbm-tools \
  ./generate -s ttl -pc "$PRODUCT_COUNT" -nof 1 \
    -dir "$DATASET_DIR_CT" \
    -fn "$DATASET_DIR_CT/dataset"

log "Dataset and test-driver parameter files written to $DATASET_DIR_HOST"
