#!/bin/sh
set -eu

readonly CERT_SOURCE="/volume2/docker/acmesh/ebi.nu_ecc"
readonly CERT_DESTINATION="/usr/syno/etc/certificate/_archive/3lbZ7c"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

if [ ! -d "$CERT_SOURCE" ]; then
	error "Certificate source directory not found: $CERT_SOURCE"
	exit 1
fi

if [ ! -d "$CERT_DESTINATION" ]; then
	error "Synology certificate destination not found: $CERT_DESTINATION"
	exit 1
fi

for file in ca.cer fullchain.cer ebi.nu.key ebi.nu.cer; do
	if [ ! -f "$CERT_SOURCE/$file" ]; then
		error "Required certificate file not found: $CERT_SOURCE/$file"
		exit 1
	fi
done

log "Updating Synology DSM certificate"

rm -f "$CERT_DESTINATION/"*.pem

cp "$CERT_SOURCE/ca.cer" \
	"$CERT_DESTINATION/chain.pem"

cp "$CERT_SOURCE/fullchain.cer" \
	"$CERT_DESTINATION/fullchain.pem"

cp "$CERT_SOURCE/ebi.nu.key" \
	"$CERT_DESTINATION/privkey.pem"

cp "$CERT_SOURCE/ebi.nu.cer" \
	"$CERT_DESTINATION/cert.pem"

chown 0:0 "$CERT_DESTINATION/"*.pem
chmod 0400 "$CERT_DESTINATION/"*.pem

log "Regenerating Synology web server configuration"

/usr/syno/bin/synow3tool --gen-all

log "Reloading nginx"

/bin/systemctl reload nginx

log "Synology DSM certificate update completed successfully"
