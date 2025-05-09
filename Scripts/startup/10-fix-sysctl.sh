#!/bin/bash
sysctl vm.overcommit_memory
sysctl net.core.somaxconn
sysctl net.ipv4.conf.all.src_valid_mark
sysctl fs.inotify.max_user_watches
sysctl -w vm.overcommit_memory=1
sysctl -w net.core.somaxconn=65535
sysctl -w net.ipv4.conf.all.src_valid_mark=1
sysctl -w net.ipv6.conf.all.accept_ra=2
sysctl -w net.ipv6.conf.default.accept_ra=2
sysctl -w fs.inotify.max_user_watches=524288
bash /volume2/docker/synology-docker/syno_docker_update.sh update -f
bash /volume1/homes/Hannibal/Synology_HDD_db-main/syno_hdd_db.sh -nr
