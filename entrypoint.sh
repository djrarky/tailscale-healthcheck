#!/bin/sh
set -eu

# start watchdog in background
/usr/local/bin/watchdog.sh &

# chain to the original image entrypoint (becomes PID 1)
exec /usr/local/bin/containerboot
