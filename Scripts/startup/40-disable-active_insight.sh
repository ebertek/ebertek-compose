#!/bin/sh
set -eu

readonly PACKAGE="ActiveInsight"
readonly FILE="/var/packages/ActiveInsight/target/configs/resource_monitor.json"
readonly KEY="enable_file_activity_module"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

if [ ! -d "/var/packages/$PACKAGE" ]; then
	log "$PACKAGE package is not installed, skipping"
	exit 0
fi

if [ ! -f "$FILE" ]; then
	error "$PACKAGE is installed but configuration file was not found: $FILE"
	exit 1
fi

if grep -Fq "\"${KEY}\": true" "$FILE"; then
	log "Disabling Active Insight file activity module"

	sed -i "s/\"${KEY}\": true/\"${KEY}\": false/g" "$FILE"

	log "Restarting ActiveInsight package"
	synopkg restart "$PACKAGE"

	log "Active Insight file activity module disabled successfully"
else
	log "Active Insight file activity module is already disabled"
fi
