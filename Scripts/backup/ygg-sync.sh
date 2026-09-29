#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RCLONE="/volume1/homes/Hannibal/bin/rclone"
RCLONE_CONFIG="$SCRIPT_DIR/rclone.conf"
RCLONE_FILTER="$SCRIPT_DIR/rclone-filter.txt"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

log "Starting ygg-sync"

log "Syncing Docker data to Hetzner Storage Box"
"$RCLONE" sync \
	--bwlimit 10M \
	--config="$RCLONE_CONFIG" \
	--fast-list \
	--filter-from "$RCLONE_FILTER" \
	--links \
	--local-no-check-updated \
	/volume2/docker/ \
	storagebox:docker

log "Docker data sync completed"

log "Syncing home directories to Hetzner Storage Box"
"$RCLONE" sync \
	--bwlimit 10M \
	--config="$RCLONE_CONFIG" \
	--fast-list \
	--filter-from "$RCLONE_FILTER" \
	--links \
	--local-no-check-updated \
	/volume1/homes/ \
	storagebox:homes

log "Home directories sync completed"

log "Syncing NetBackup to Hetzner Storage Box"
"$RCLONE" sync \
	--bwlimit 10M \
	--config="$RCLONE_CONFIG" \
	--fast-list \
	--filter-from "$RCLONE_FILTER" \
	--links \
	--local-no-check-updated \
	/volume1/NetBackup/ \
	storagebox:NetBackup

log "NetBackup sync completed"
log "ygg-sync completed successfully"
