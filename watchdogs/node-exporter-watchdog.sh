#!/usr/bin/env bash
# Watchdog for Node Exporter; restarts the service if /metrics is not responsive

set -euo pipefail

URL="http://localhost:9100/metrics"

if curl -fs --max-time 5 "$URL" >/dev/null; then
  echo "$(date '+%F %T') Node Exporter OK"
else
  echo "$(date '+%F %T') Node Exporter DOWN -> restarting"
  systemctl restart node_exporter
fi
