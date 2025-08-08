#!/usr/bin/env bash
# Watchdog for Prometheus; restarts the service if /metrics is not responsive

set -euo pipefail

URL="http://localhost:9090/metrics"

if curl -fs --max-time 5 "$URL" >/dev/null; then
  echo "$(date '+%F %T') Prometheus OK"
else
  echo "$(date '+%F %T') Prometheus DOWN -> restarting"
  systemctl restart prometheus
fi
