#!/bin/sh
set -eu

readonly CERT_SOURCE="/volume2/docker/acmesh/ebi.nu_ecc/ebi.nu.pfx"
readonly CERT_DESTINATION="/volume2/docker/plex/config/ebi.nu.pfx"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

PLEX_CONTAINER=$(
	docker ps \
		--filter "label=com.docker.compose.service=plex" \
		--format '{{.ID}}' |
		head -n1
)

if [ -z "$PLEX_CONTAINER" ]; then
	error "No running Plex container found"
	exit 1
fi

if [ ! -f "$CERT_SOURCE" ]; then
	error "Plex certificate source not found: $CERT_SOURCE"
	exit 1
fi

log "Updating Plex certificate"

rm -f "$CERT_DESTINATION"
cp "$CERT_SOURCE" "$CERT_DESTINATION"
chown docker:users "$CERT_DESTINATION"
chmod 0644 "$CERT_DESTINATION"

log "Restarting Plex Media Server process"

docker exec "$PLEX_CONTAINER" sh -c '
	pid=$(pidof "Plex Media Server")

	if [ -z "$pid" ]; then
		echo "Plex Media Server process not found" >&2
		exit 1
	fi

	kill -9 "$pid"
'

log "Plex certificate update completed successfully"
