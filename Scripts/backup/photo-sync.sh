#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RCLONE="/var/services/homes/Hannibal/bin/rclone"
RCLONE_CONFIG="$SCRIPT_DIR/rclone.conf"
RCLONE_FILTER="$SCRIPT_DIR/rclone-filter.txt"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

log "Starting photo-sync"

log "Syncing Pictures to Hetzner Storage Box"
"$RCLONE" sync \
	--bwlimit 10M \
	--config="$RCLONE_CONFIG" \
	--fast-list \
	--filter-from "$RCLONE_FILTER" \
	--links \
	--local-no-check-updated \
	-v \
	/volume1/photo/Pictures/ \
	storagebox:Pictures

log "Pictures sync completed"

log "Syncing Movies to Hetzner Storage Box"
"$RCLONE" sync \
	--bwlimit 10M \
	--config="$RCLONE_CONFIG" \
	--fast-list \
	--filter-from "$RCLONE_FILTER" \
	--links \
	--local-no-check-updated \
	-v \
	/volume1/video/Movies/ \
	storagebox:Movies

log "Movies sync completed"
log "photo-sync completed successfully"
