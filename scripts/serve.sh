#!/usr/bin/env bash
# Start/stop/wait-for the $BACKEND container (gengodb or jena-fuseki) serving
# ./data/db/... on $BACKEND_PORT.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

ACTION="${1:-start}"

case "$ACTION" in
  start)
    [ -f "$DB_DIR_HOST/.initialized" ] || fail "DB directory not initialized at $DB_DIR_HOST - run init-db.sh first"
    log "Starting $BACKEND_SERVICE on port $BACKEND_PORT, serving $DB_DIR_CT"
    docker compose up -d "$BACKEND_SERVICE"
    "$0" wait
    ;;
  wait)
    URL="http://localhost:${BACKEND_PORT}${BACKEND_SPARQL_PATH}"
    log "Waiting up to ${SERVE_TIMEOUT}s for $BACKEND_SERVICE to answer HTTP at $URL..."
    DEADLINE=$(( $(date +%s) + SERVE_TIMEOUT ))
    while [ "$(date +%s)" -lt "$DEADLINE" ]; do
      CODE="$(curl -s -o /dev/null -m 10 -w '%{http_code}' -G "$URL" \
        --data-urlencode 'query=ASK { ?s ?p ?o }' 2>/dev/null || true)"
      if [ -n "$CODE" ] && [ "$CODE" != "000" ]; then
        log "$BACKEND_SERVICE is answering HTTP (status $CODE)."
        exit 0
      fi
      if [ -z "$(docker compose ps -q --status running "$BACKEND_SERVICE")" ]; then
        log "$BACKEND_SERVICE container is not running. Recent logs:"
        docker compose logs --tail=100 "$BACKEND_SERVICE" >&2
        exit 1
      fi
      sleep 2
    done
    log "Timed out after ${SERVE_TIMEOUT}s waiting for $BACKEND_SERVICE. Recent logs:"
    docker compose logs --tail=100 "$BACKEND_SERVICE" >&2
    exit 1
    ;;
  stop)
    log "Stopping $BACKEND_SERVICE server"
    docker compose stop "$BACKEND_SERVICE"
    ;;
  logs)
    docker compose logs -f "$BACKEND_SERVICE"
    ;;
  *)
    echo "Usage: $0 {start|wait|stop|logs}" >&2
    exit 1
    ;;
esac
