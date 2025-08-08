#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
API_KEY="${API_KEY:?Set API_KEY env var}"

for dashboard in "$(dirname "$0")"/dashboards/*.json; do
  echo "Importing $dashboard"
  curl -sS -X POST -H "Authorization: Bearer $API_KEY"        -H "Content-Type: application/json"        -d @"$dashboard"        "$GRAFANA_URL/api/dashboards/db" | jq .
done
