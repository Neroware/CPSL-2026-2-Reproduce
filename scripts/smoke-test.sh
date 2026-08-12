#!/usr/bin/env bash
# Sanity-check that the running $BACKEND server actually answers SPARQL
# queries at BACKEND_SPARQL_PATH before spending time on a full benchmark run.
#
# Uses SELECT since that's what the actual "explore" query mix mostly is;
# ASK/DESCRIBE/CONSTRUCT are accepted too (GengoDB: 200 + graceful empty
# result for the latter two, see hosts/GengoDB/known-issues/README.md item 3;
# Fuseki: real results, it's a full SPARQL implementation).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

URL="http://localhost:${BACKEND_PORT}${BACKEND_SPARQL_PATH}"
QUERY='SELECT * WHERE { ?s ?p ?o } LIMIT 1'

log "Smoke-testing SPARQL endpoint at $URL ($BACKEND)"

ATTEMPTS=5
for i in $(seq 1 "$ATTEMPTS"); do
  if RESPONSE=$(curl -fsS -G "$URL" --data-urlencode "query=$QUERY"); then
    break
  fi
  if [ "$i" -eq "$ATTEMPTS" ]; then
    log "Smoke test FAILED: could not get a successful response from $URL after $ATTEMPTS attempts"
    log "BACKEND_SPARQL_PATH is currently '$BACKEND_SPARQL_PATH' - if $BACKEND serves"
    log "SPARQL on a different path, set GENGODB_SPARQL_PATH/FUSEKI_DATASET and retry."
    exit 1
  fi
  log "Attempt $i/$ATTEMPTS failed (server may still be coming up), retrying..."
  sleep 1
done

log "Smoke test succeeded. Sample response:"
echo "$RESPONSE" | head -c 400
echo
