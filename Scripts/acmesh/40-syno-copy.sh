#!/usr/bin/env bash

set -euo pipefail

readonly SOURCE_DIR="/volume2/docker/acmesh/ebi.nu_ecc"

readonly REMOTE_HOST="ygg.ebi.nu"
readonly REMOTE_USER="Hannibal"
readonly REMOTE_PORT="38022"

readonly REMOTE_TMP="/tmp/ygg-syno-cert"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

for file in cert.pem fullchain.pem privkey.pem; do
	if [[ ! -f "${SOURCE_DIR}/${file}" ]]; then
		error "Certificate source not found: ${SOURCE_DIR}/${file}"
		exit 1
	fi
done

log "Preparing temporary certificate directory on ${REMOTE_HOST}"

ssh \
	-p "$REMOTE_PORT" \
	"${REMOTE_USER}@${REMOTE_HOST}" \
	"rm -rf '$REMOTE_TMP' && mkdir -p '$REMOTE_TMP'"

log "Copying certificate files to ${REMOTE_HOST}"

scp \
	-P "$REMOTE_PORT" \
	"${SOURCE_DIR}/cert.pem" \
	"${SOURCE_DIR}/fullchain.pem" \
	"${SOURCE_DIR}/privkey.pem" \
	"${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TMP}/"

log "Synology certificate files copied successfully"
