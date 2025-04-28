#!/bin/bash
set -e
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_NAME%.sh}.txt"
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "Error: $ENV_FILE file not found!"
  exit 1
fi

echo Backing up to Yggdrasil...
rsync -e "ssh -p $PORT" -av --exclude docker/ /mnt/data/ "$USER@$HOST:/volume1/NetBackup/backupdata/"
echo Backing up to Hetzner...
/usr/bin/rclone sync --bwlimit 10M --config=/root/ygg-compose/Scripts/backup/rclone.conf --fast-list --filter-from /root/ygg-compose/Scripts/backup/rclone-filter.txt --links --local-no-check-updated /mnt/data/ storagebox:data
echo Done!
