FROM ghcr.io/tailscale/tailscale:latest

# Expose /healthz and set watchdog defaults
ENV TS_ENABLE_HEALTH_CHECK=true \
    TS_WATCHDOG_INTERVAL=30 \
    TS_WATCHDOG_START_PERIOD=60 \
    TS_WATCHDOG_BACKEND_GRACE=180 \
    TS_WATCHDOG_FAILS=2 \
    TS_WATCHDOG_REQUIRE_BOTH=true \
    TS_WATCHDOG_VERBOSE=false

# BusyBox wget is enough for /healthz
RUN apk add --no-cache wget

# Add scripts
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY watchdog.sh /usr/local/bin/watchdog.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/watchdog.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=1 \
  CMD sh -c 'wget -q --spider --timeout=4 "http://127.0.0.1:9002/healthz" || { kill -s TERM 1; exit 1; }'

# Start watchdog, then exec the original entrypoint as PID 1
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
