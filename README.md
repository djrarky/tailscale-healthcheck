# Tailscale + Watchdog (Docker)

A tiny wrapper around `ghcr.io/tailscale/tailscale:latest` that adds a lightweight watchdog to restart the container if health checks fail.

## What this image does

- Enables Tailscale's built-in health check (`/healthz` on `127.0.0.1:9002`).
- Adds a watchdog that terminates PID 1 on health failure (so your orchestrator restarts the container).
- Installs BusyBox `wget` for probing `/healthz`.
- Uses `entrypoint.sh` to start the watchdog, then execs the original Tailscale entrypoint.

## Environment variables (defaults)

These are set in the Dockerfile; override with `-e KEY=value` if needed.

- `TS_ENABLE_HEALTH_CHECK=true`
- `TS_WATCHDOG_INTERVAL=30`
- `TS_WATCHDOG_START_PERIOD=60`
- `TS_WATCHDOG_BACKEND_GRACE=180`
- `TS_WATCHDOG_FAILS=2`
- `TS_WATCHDOG_REQUIRE_BOTH=true`
- `TS_WATCHDOG_VERBOSE=false`

## Health check

A Docker `HEALTHCHECK` hits `http://127.0.0.1:9002/healthz` every 30 seconds (5s timeout, 90s start period). On failure it sends `TERM` to PID 1, allowing the runtime to restart the container.
