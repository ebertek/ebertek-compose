#!/bin/bash
bash /volume1/docker/ebertek-compose/Scripts/startup/10-fix-sysctl.sh
sh /volume1/docker/ebertek-compose/Scripts/startup/20-insmod-tun.sh
bash /volume1/docker/ebertek-compose/Scripts/startup/30-macvlan.sh
sh /volume1/docker/ebertek-compose/Scripts/startup/40-disable-active_insight.sh
bash /volume1/docker/ebertek-compose/Scripts/startup/50-sdp.sh
bash /volume1/docker/ebertek-compose/Scripts/startup/60-rclone.sh
bash /volume1/docker/ebertek-compose/Scripts/startup/70-youtube.sh
