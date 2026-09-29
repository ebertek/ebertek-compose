#!/bin/bash

set -u

failures=0

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

run() {
	log "Running: $*"

	if "$@"; then
		log "Completed: $*"
	else
		status=$?
		error "Failed with exit code ${status}: $*"
		((failures += 1))
	fi
}

log "Starting Synology startup scripts"

run bash /volume2/docker/ebertek-compose/Scripts/startup/10-fix-sysctl.sh
run sh /volume2/docker/ebertek-compose/Scripts/startup/20-insmod-tun.sh
run sh /volume2/docker/ebertek-compose/Scripts/startup/40-disable-active_insight.sh
run bash /volume2/docker/ebertek-compose/Scripts/startup/50-sdp.sh
run bash /volume2/docker/ebertek-compose/Scripts/startup/60-rclone.sh
run bash /volume2/docker/ebertek-compose/Scripts/startup/70-youtube.sh
run bash /volume1/homes/Hannibal/Synology_HDD_db-main/syno_hdd_db.sh -nr

if ((failures > 0)); then
	error "Startup completed with ${failures} failed task(s)"
	exit 1
fi

log "All startup scripts completed successfully"
