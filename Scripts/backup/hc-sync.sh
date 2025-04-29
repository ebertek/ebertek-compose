#!/bin/sh
set -e
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_DIR}/${SCRIPT_NAME%.sh}.txt"
[ -f "$ENV_FILE" ] || {
	echo "Error: $ENV_FILE file not found!"
	exit 1
}
while IFS='=' read -r key value; do
	[ -z "$key" ] && continue
	case "$key" in
	\#*) continue ;;
	esac
	export "$key=$value"
done < "$ENV_FILE"

echo Backing up to Yggdrasil...
rsync -e "ssh -p $PORT" -av --exclude docker/ /mnt/data/ "$USER@$HOST:/volume1/NetBackup/backupdata/"
echo Backing up to Hetzner...
/usr/bin/rclone sync --bwlimit 10M --config=/root/ygg-compose/Scripts/backup/rclone.conf --fast-list --filter-from /root/ygg-compose/Scripts/backup/rclone-filter.txt --links --local-no-check-updated /mnt/data/ storagebox:data
echo Done!
