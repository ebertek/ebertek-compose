#!/bin/bash
{
  /var/services/homes/Hannibal/bin/rclone sync --bwlimit 10M --config=/volume1/docker/ygg-compose/Scripts/backup/rclone.conf --fast-list --filter-from /volume1/docker/ygg-compose/Scripts/backup/rclone-filter.txt --links --local-no-check-updated -v /volume1/photo/Pictures/ storagebox:Pictures
  /var/services/homes/Hannibal/bin/rclone sync --bwlimit 10M --config=/volume1/docker/ygg-compose/Scripts/backup/rclone.conf --fast-list --filter-from /volume1/docker/ygg-compose/Scripts/backup/rclone-filter.txt --links --local-no-check-updated -v /volume1/video/Movies/ storagebox:Movies
} >"/var/services/homes/Hannibal/Logs/photo-sync/$(date +%F_%H-%M-%S.log)" 2>&1
