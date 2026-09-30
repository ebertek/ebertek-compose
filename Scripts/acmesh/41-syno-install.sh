#!/usr/bin/env bash

set -euo pipefail

readonly CERT_DESC="Yggdrasil wildcard"
readonly ARCHIVE_ROOT="/usr/syno/etc/certificate/_archive"
readonly INFO_FILE="${ARCHIVE_ROOT}/INFO"
readonly SOURCE_DIR="/tmp/ygg-syno-cert"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

if [[ "$(id -u)" -ne 0 ]]; then
	error "This script must be run as root"
	exit 1
fi

for file in ebi.nu.cer ca.cer fullchain.cer ebi.nu.key; do
	if [[ ! -f "${SOURCE_DIR}/${file}" ]]; then
		error "Certificate source not found: ${SOURCE_DIR}/${file}"
		exit 1
	fi
done

if [[ ! -f "$INFO_FILE" ]]; then
	error "Synology certificate metadata not found: $INFO_FILE"
	exit 1
fi

cert_id=$(
	python3 - "$CERT_DESC" "$INFO_FILE" <<'PY'
import json
import sys

desc = sys.argv[1]
path = sys.argv[2]

with open(path, encoding="utf-8") as f:
    data = json.load(f)

matches = [
    cert_id
    for cert_id, config in data.items()
    if config.get("desc") == desc
]

if len(matches) != 1:
    print(
        f"Expected exactly one certificate with description {desc!r}, "
        f"found {len(matches)}",
        file=sys.stderr,
    )
    sys.exit(1)

print(matches[0])
PY
)

DEST="${ARCHIVE_ROOT}/${cert_id}"

if [[ ! -d "$DEST" ]]; then
	error "Synology certificate destination not found: $DEST"
	exit 1
fi

log "Installing certificate into ${DEST}"

cp "${SOURCE_DIR}/ebi.nu.cer" "${DEST}/cert.pem"
cp "${SOURCE_DIR}/ca.cer" "${DEST}/chain.pem"
cp "${SOURCE_DIR}/fullchain.cer" "${DEST}/fullchain.pem"
cp "${SOURCE_DIR}/ebi.nu.key" "${DEST}/privkey.pem"

chown root:root \
	"${DEST}/cert.pem" \
	"${DEST}/chain.pem" \
	"${DEST}/fullchain.pem" \
	"${DEST}/privkey.pem"

chmod 0400 \
	"${DEST}/cert.pem" \
	"${DEST}/chain.pem" \
	"${DEST}/fullchain.pem" \
	"${DEST}/privkey.pem"

log "Regenerating Synology certificate configuration"
synow3tool --gen-all

log "Reloading nginx"
synosystemctl reload nginx

rm -rf "$SOURCE_DIR"

log "Synology certificate updated successfully"
