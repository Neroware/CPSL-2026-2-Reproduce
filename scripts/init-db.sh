#!/usr/bin/env bash
# Initialize a $BACKEND database directory (./data/db/...) by loading the
# generated dataset into the default graph, dispatching to the right
# per-backend loading strategy below.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

if [ -f "$DB_DIR_HOST/.initialized" ] && [ "${FORCE:-0}" != "1" ]; then
  log "DB directory already initialized at $DB_DIR_HOST (set FORCE=1 to reinitialize)"
  exit 0
fi

[ -f "$DATASET_DIR_HOST/dataset.ttl" ] || fail "Dataset not found at $DATASET_DIR_HOST/dataset.ttl - run generate-dataset.sh first"

mkdir -p "$DB_DIR_HOST"
rm -f "$DB_DIR_HOST/.initialized"

# ---------------------------------------------------------------------------
init_gengodb() {
  ln -sf "$DATASET_DIR_CT/dataset.ttl" "$DB_DIR_HOST/dataset.ttl"

  cat > "$DB_DIR_HOST/initialize.sparql" <<EOF
PREFIX db: <gengodb://sparql/settings/>
DESCRIBE ?entity WHERE { ?entity db:capacity $DB_CAPACITY . };

LOAD <file://dataset.ttl> INTO GRAPH <file://dataset.ttl#rdf>;
LOAD <file://dataset.ttl> INTO GRAPH <gengodb://sparql/settings/defaultGraph#rdf>;

PREFIX db: <gengodb://sparql/settings/>
DESCRIBE ?entity WHERE {
    ?entity db:persists true .
    ?entity db:defaultGraph <file://dataset.ttl#rdf> .
    ?entity db:initialize true .
};
EOF

  log "Initializing GengoDB directory at $DB_DIR_HOST (capacity=$DB_CAPACITY)"
  set +e
  OUT="$(docker compose run --rm gengodb bash -lc \
    "/gengodb/build/lingodb-release/sparql '$DB_DIR_CT_SLASH' < '${DB_DIR_CT}/initialize.sparql'" 2>&1)"
  STATUS=$?
  set -e
  echo "$OUT"

  if [ "$STATUS" -ne 0 ]; then
    fail "sparql REPL exited with status $STATUS - see output above (this may be the LOAD segfault documented in hosts/GengoDB/known-issues/README.md)"
  fi
  if echo "$OUT" | grep -q '^Error:'; then
    fail "sparql REPL reported an error during initialization - see output above"
  fi
}

# ---------------------------------------------------------------------------
init_fuseki() {
  cat > "$DB_DIR_HOST/load.sh" <<EOF
set -euo pipefail
java -jar fuseki-server.jar --loc="$DB_DIR_CT" --update --port=3030 "/$FUSEKI_DATASET" &
FUSEKI_PID=\$!
trap 'kill \$FUSEKI_PID 2>/dev/null || true' EXIT

echo "Waiting for Fuseki to accept SPARQL queries..." >&2
READY=0
for i in \$(seq 1 30); do
  if curl -fsS -G "http://localhost:3030/$FUSEKI_DATASET/sparql" --data-urlencode "query=ASK { ?s ?p ?o }" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done
[ "\$READY" -eq 1 ] || { echo "Fuseki did not become ready in time" >&2; exit 1; }

echo "Loading $DATASET_DIR_CT/dataset.ttl into the default graph..." >&2
curl -fsS -X PUT -H "Content-Type: text/turtle" \\
  --data-binary "@$DATASET_DIR_CT/dataset.ttl" \\
  "http://localhost:3030/$FUSEKI_DATASET/data?default"
echo "Load complete." >&2
EOF

  log "Initializing Fuseki TDB2 directory at $DB_DIR_HOST"
  docker compose run --rm jena-fuseki bash "$DB_DIR_CT/load.sh"
}

# ---------------------------------------------------------------------------
case "$BACKEND" in
  gengodb) init_gengodb ;;
  fuseki)  init_fuseki ;;
esac

touch "$DB_DIR_HOST/.initialized"
log "DB directory initialized"
