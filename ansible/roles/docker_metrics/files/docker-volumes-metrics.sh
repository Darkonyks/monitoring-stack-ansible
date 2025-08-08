#!/usr/bin/env bash
# Export per-volume sizes (bytes) for Docker named volumes matching "sremgas-*"
# Output format is Prometheus textfile collector (.prom)

set -euo pipefail

OUT="/var/lib/node_exporter/textfile/docker_volumes.prom"
TMP="$(mktemp)"

{
  echo "# HELP docker_volume_size_bytes Size of Docker named volumes"
  echo "# TYPE docker_volume_size_bytes gauge"
} > "$TMP"

# Iterate volumes with 'sremgas-' prefix; get actual Mountpoint via docker inspect
while IFS= read -r VOL; do
  MP="$(docker volume inspect -f '{{ .Mountpoint }}' "$VOL" 2>/dev/null || true)"
  if [ -z "$MP" ] || [ ! -d "$MP" ]; then
    continue
  fi
  SIZE_BYTES="$(du -sb "$MP" 2>/dev/null | awk '{print $1}')"
  SIZE_BYTES="${SIZE_BYTES:-0}"
  echo "docker_volume_size_bytes{volume=\"${VOL}\"} ${SIZE_BYTES}" >> "$TMP"
done < <(docker volume ls --format '{{.Name}}' | grep '^sremgas-')

mv "$TMP" "$OUT"
