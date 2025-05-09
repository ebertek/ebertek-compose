#!/bin/bash
{
	/var/services/homes/Hannibal/bin/rclone sync --bwlimit 10M --config=/volume2/docker/ygg-compose/Scripts/backup/rclone.conf --fast-list --filter-from /volume2/docker/ygg-compose/Scripts/backup/rclone-filter.txt --links --local-no-check-updated /volume2/docker/ storagebox:docker
	/var/services/homes/Hannibal/bin/rclone sync --bwlimit 10M --config=/volume2/docker/ygg-compose/Scripts/backup/rclone.conf --fast-list --filter-from /volume2/docker/ygg-compose/Scripts/backup/rclone-filter.txt --links --local-no-check-updated /var/services/homes/ storagebox:homes
	/var/services/homes/Hannibal/bin/rclone sync --bwlimit 10M --config=/volume2/docker/ygg-compose/Scripts/backup/rclone.conf --fast-list --filter-from /volume2/docker/ygg-compose/Scripts/backup/rclone-filter.txt --links --local-no-check-updated /volume1/NetBackup/ storagebox:NetBackup
} >"/var/services/homes/Hannibal/Logs/ygg-sync/$(date +%F_%H-%M-%S.log)" 2>&1
