#!/bin/sh
set -eu

readonly FILE="/var/packages/ActiveInsight/target/configs/resource_monitor.json"
readonly KEY="enable_file_activity_module"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

if [ ! -f "$FILE" ]; then
	error "Active Insight configuration file not found: $FILE"
	exit 1
fi

if grep -Fq "\"${KEY}\": true" "$FILE"; then
	log "Disabling Active Insight file activity module"

	sed -i "s/\"${KEY}\": true/\"${KEY}\": false/g" "$FILE"

	log "Restarting ActiveInsight package"
	synopkg restart ActiveInsight

	log "Active Insight file activity module disabled successfully"
else
	log "Active Insight file activity module is already disabled"
fi
