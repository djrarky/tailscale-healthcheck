#!/bin/sh
set -eu

# ---- Tunables (override via container env) --------------------------
INTERVAL="${TS_WATCHDOG_INTERVAL:-30}"            # seconds between checks
START_PERIOD="${TS_WATCHDOG_START_PERIOD:-60}"    # initial boot grace
BACKEND_GRACE="${TS_WATCHDOG_BACKEND_GRACE:-180}" # extra time before enforcing backend
FAILS_NEEDED="${TS_WATCHDOG_FAILS:-2}"            # consecutive failures before restart
REQUIRE_BOTH="${TS_WATCHDOG_REQUIRE_BOTH:-true}"  # enforce both after grace
VERBOSE="${TS_WATCHDOG_VERBOSE:-false}"           # verbose logging of watchdog events

log() { printf '%s watchdog: %s\n' "$(date -u +%FT%TZ)" "$*" >&2; }

# ---- Probes (exit 0 = OK) ---------------------------------------------------
probe_liveness() {
  wget -q --spider --timeout=4 "http://127.0.0.1:9002/healthz"
}

probe_backend() {
  # Exit 0 only when BackendState == Running
  S="$(timeout 4s /usr/local/bin/tailscale --socket=/tmp/tailscaled.sock status --json 2>/dev/null \
      | tr -d '\r\n' \
      | grep -Eo '"BackendState"[[:space:]]*:[[:space:]]*"[^"]*"' \
      | head -n1 | cut -d'"' -f4)"
  [ "$S" = "Running" ]
}

# ---- Main loop --------------------------------------------------------------
sleep "$START_PERIOD"
start_epoch="$(date +%s)"
fails=0

log "watchdog starting: interval=$INTERVAL start_grace=$START_PERIOD backend_grace=$BACKEND_GRACE require_both=$REQUIRE_BOTH"

while :; do
  liveness_ok=1; backend_ok=1

  if ! probe_liveness; then liveness_ok=0; fi

  # Only enforce backend after the extra grace window
  enforce_backend=0
  if [ "$REQUIRE_BOTH" = "true" ]; then
    now="$(date +%s)"
    if [ $(( now - start_epoch )) -ge "$BACKEND_GRACE" ]; then
      enforce_backend=1
    fi
  fi

  if [ "$enforce_backend" -eq 1 ]; then
    if ! probe_backend; then backend_ok=0; fi
  fi

  ok=0
  if [ "$enforce_backend" -eq 1 ]; then
    [ $liveness_ok -eq 1 ] && [ $backend_ok -eq 1 ] && ok=1
  else
    [ $liveness_ok -eq 1 ] && ok=1
  fi

  if [ "$VERBOSE" = "true" ]; then
    if [ "$REQUIRE_BOTH" = "true" ] && [ "$enforce_backend" -eq 1 ]; then
      # Backend is enforced, so report both probes
      log "tick: liveness=$liveness_ok backend=$backend_ok"
    else
      # Only liveness is relevant (backend not enforced yet or REQUIRE_BOTH=false)
      log "tick: liveness=$liveness_ok"
    fi
  fi

  if [ $ok -eq 1 ]; then
    [ $fails -gt 0 ] && log "recovered (liveness=$liveness_ok backend=$backend_ok enforce_backend=$enforce_backend)"
    fails=0
  else
    fails=$((fails+1))
    log "probe failed ($fails/$FAILS_NEEDED) liveness=$liveness_ok backend=$backend_ok enforce_backend=$enforce_backend"
    if [ $fails -ge "$FAILS_NEEDED" ]; then
      log "terminating PID 1 to force container restart"
      kill -s TERM 1
      sleep 5
      kill -s KILL 1 2>/dev/null || true
      exit 1
    fi
  fi
  sleep "$INTERVAL"
done
