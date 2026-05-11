#!/bin/bash

run() {
	echo "[$(date '+%F %T')] Running: $*"
	"$@" || echo "[$(date '+%F %T')] FAILED: $*" >&2
}

run bash /volume2/docker/ebertek-compose/Scripts/startup/10-fix-sysctl.sh
run sh /volume2/docker/ebertek-compose/Scripts/startup/20-insmod-tun.sh
# run bash /volume2/docker/ebertek-compose/Scripts/startup/30-macvlan.sh
run sh /volume2/docker/ebertek-compose/Scripts/startup/40-disable-active_insight.sh
run bash /volume2/docker/ebertek-compose/Scripts/startup/50-sdp.sh
run bash /volume2/docker/ebertek-compose/Scripts/startup/60-rclone.sh
run bash /volume2/docker/ebertek-compose/Scripts/startup/70-youtube.sh
# if cd /volume2/docker/_backup/; then run bash /volume2/docker/synology-docker/syno_docker_update.sh update -f -p /volume2/docker/_backup; fi
run bash /volume1/homes/Hannibal/Synology_HDD_db-main/syno_hdd_db.sh -nr
