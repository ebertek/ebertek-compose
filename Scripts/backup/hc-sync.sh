#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_DIR}/${SCRIPT_NAME%.sh}.txt"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

if [ ! -f "$ENV_FILE" ]; then
	error "$ENV_FILE file not found"
	exit 1
fi

while IFS='=' read -r key value; do
	[ -z "$key" ] && continue

	case "$key" in
	\#*) continue ;;
	esac

	export "$key=$value"
done <"$ENV_FILE"

for var in HOST PORT USER; do
	eval "value=\${$var:-}"

	if [ -z "$value" ]; then
		error "Required variable $var is not set"
		exit 1
	fi
done

log "Starting hc-sync"

log "Backing up /mnt/data to Yggdrasil"
rsync \
	-e "ssh -p $PORT" \
	-av \
	--delete \
	--exclude docker/ \
	/mnt/data/ \
	"$USER@$HOST:/volume1/NetBackup/backupdata/"

log "Yggdrasil backup completed"

log "Backing up /mnt/data to Hetzner Storage Box"
/usr/bin/rclone sync \
	--bwlimit 10M \
	--config="$SCRIPT_DIR/rclone.conf" \
	--fast-list \
	--filter-from "$SCRIPT_DIR/rclone-filter.txt" \
	--links \
	--local-no-check-updated \
	/mnt/data/ \
	storagebox:data

log "Hetzner backup completed"

log "hc-sync completed successfully"
