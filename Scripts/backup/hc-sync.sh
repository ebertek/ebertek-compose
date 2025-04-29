#!/bin/sh
set -e
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_NAME%.sh}.txt"
[ -f "$ENV_FILE" ] || {
	echo "Error: $ENV_FILE file not found!"
	exit 1
}
export "$(grep -v '^#' "$ENV_FILE" | xargs)"

echo Backing up to Yggdrasil...
rsync -e "ssh -p $PORT" -av --exclude docker/ /mnt/data/ "$USER@$HOST:/volume1/NetBackup/backupdata/"
echo Backing up to Hetzner...
/usr/bin/rclone sync --bwlimit 10M --config=/root/ygg-compose/Scripts/backup/rclone.conf --fast-list --filter-from /root/ygg-compose/Scripts/backup/rclone-filter.txt --links --local-no-check-updated /mnt/data/ storagebox:data
echo Done!
