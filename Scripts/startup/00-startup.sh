#!/bin/bash
bash /volume2/docker/ebertek-compose/Scripts/startup/10-fix-sysctl.sh
sh /volume2/docker/ebertek-compose/Scripts/startup/20-insmod-tun.sh
bash /volume2/docker/ebertek-compose/Scripts/startup/30-macvlan.sh
sh /volume2/docker/ebertek-compose/Scripts/startup/40-disable-active_insight.sh
bash /volume2/docker/ebertek-compose/Scripts/startup/50-sdp.sh
bash /volume2/docker/ebertek-compose/Scripts/startup/60-rclone.sh
bash /volume2/docker/ebertek-compose/Scripts/startup/70-youtube.sh
cd /volume2/docker/_backup/
bash /volume2/docker/synology-docker/syno_docker_update.sh update -f -p /volume2/docker/_backup
bash /volume1/homes/Hannibal/Synology_HDD_db-main/syno_hdd_db.sh -nr
