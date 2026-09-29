#!/bin/bash
set -euo pipefail

DOWNLOAD_DIR="/volume1/Downloads/YouTube/thang010146"
ARCHIVE_FILE="/volume1/Downloads/YouTube/thang010146.txt"
YT_DLP="/var/services/homes/Hannibal/bin/yt-dlp"
CHANNEL_URL="https://www.youtube.com/channel/UCli_RJkGWfZvw4IlDLHNCQg/videos"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

log "Starting thang010146 download"

cd "$DOWNLOAD_DIR"

"$YT_DLP" \
	--download-archive "$ARCHIVE_FILE" \
	--restrict-filenames \
	--compat-options filename,filename-sanitization \
	--ignore-errors \
	--format b \
	--add-metadata \
	--embed-subs \
	--all-subs \
	"$CHANNEL_URL"

log "Updating permissions on downloaded MP4 files"

find . \
	-maxdepth 1 \
	-type f \
	-name '*.mp4' \
	-exec chmod 644 {} +

log "thang010146 completed successfully"
