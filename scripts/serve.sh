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
    log "Waiting for $BACKEND_SERVICE to accept connections on port $BACKEND_PORT..."
    for _ in $(seq 1 60); do
      if (exec 3<>"/dev/tcp/localhost/$BACKEND_PORT") 2>/dev/null; then
        log "$BACKEND_SERVICE is accepting connections on port $BACKEND_PORT."
        exit 0
      fi
      sleep 2
    done
    log "Timed out waiting for $BACKEND_SERVICE to listen on port $BACKEND_PORT. Recent logs:"
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
