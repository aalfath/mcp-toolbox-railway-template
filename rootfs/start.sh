#!/bin/sh
# Start MCP Toolbox (private, 127.0.0.1) and the Caddy bearer-token gate ($PORT).
# If either process stops, stop the other and exit non-zero so Railway restarts
# the service (ON_FAILURE also works on Free and Trial plans).
set -eu

export PORT="${PORT:-8080}"
export TOOLBOX_INTERNAL_PORT="${TOOLBOX_INTERNAL_PORT:-5000}"
TOOLBOX_PREBUILT="${TOOLBOX_PREBUILT:-postgres}"
# Go runtime: stay well inside a 0.5 GB Railway plan.
export GOMEMLIMIT="${GOMEMLIMIT:-300MiB}"

log() { echo "[start] $*"; }

token="${MCP_AUTH_TOKEN:-}"
case "$token" in
  ""|*[!A-Za-z0-9._~-]*)
    log "MCP_AUTH_TOKEN must be set and contain only letters, digits and . _ ~ - (refusing to start an open MCP server)" >&2
    exit 64 ;;
esac
if [ "${#token}" -lt 24 ]; then
  log "MCP_AUTH_TOKEN must be at least 24 characters" >&2
  exit 64
fi

# Tool configuration: a custom tools.yaml from TOOLS_YAML (raw YAML) or
# TOOLS_YAML_BASE64 if set, otherwise Toolbox's prebuilt tools for $TOOLBOX_PREBUILT.
set --
if [ -n "${TOOLS_YAML_BASE64:-}" ]; then
  printf '%s' "$TOOLS_YAML_BASE64" | base64 -d > /tmp/tools.yaml
  set -- --config /tmp/tools.yaml
  log "using tools.yaml from TOOLS_YAML_BASE64"
elif [ -n "${TOOLS_YAML:-}" ]; then
  printf '%s\n' "$TOOLS_YAML" > /tmp/tools.yaml
  set -- --config /tmp/tools.yaml
  log "using tools.yaml from TOOLS_YAML"
else
  for p in $(echo "$TOOLBOX_PREBUILT" | tr ',' ' '); do set -- "$@" --prebuilt "$p"; done
  log "using prebuilt tools: $TOOLBOX_PREBUILT"
fi

# Wait (up to 120 s) for the database so a first deploy doesn't race Postgres.
if [ -n "${POSTGRES_HOST:-}" ]; then
  i=0
  until nc -z -w 2 "$POSTGRES_HOST" "${POSTGRES_PORT:-5432}" 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then log "database $POSTGRES_HOST:${POSTGRES_PORT:-5432} not reachable after 120 s" >&2; exit 1; fi
    sleep 2
  done
  log "database $POSTGRES_HOST:${POSTGRES_PORT:-5432} is reachable"
fi

/toolbox "$@" --address 127.0.0.1 --port "$TOOLBOX_INTERNAL_PORT" ${TOOLBOX_EXTRA_ARGS:-} &
toolbox_pid=$!
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
caddy_pid=$!
log "toolbox pid $toolbox_pid, caddy pid $caddy_pid, listening on :$PORT"

stopping=0
term() { stopping=1; kill "$toolbox_pid" "$caddy_pid" 2>/dev/null || true; }
trap term TERM INT

# BusyBox `wait -n` doesn't return on the first child exit, so poll.
while kill -0 "$toolbox_pid" 2>/dev/null && kill -0 "$caddy_pid" 2>/dev/null; do
  sleep 2
done
kill "$toolbox_pid" "$caddy_pid" 2>/dev/null || true
wait 2>/dev/null || true
if [ "$stopping" = 1 ]; then log "stopped"; exit 0; fi
log "a process exited unexpectedly; exiting 1 so Railway restarts the service" >&2
exit 1
