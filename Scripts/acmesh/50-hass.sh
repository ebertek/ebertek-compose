#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_DIR}/${SCRIPT_NAME%.sh}.txt"

CERT_SOURCE="/volume2/docker/acmesh/ebi.nu_ecc"
HASS_SSL_DIR="/volume2/docker/hass/config/ssl"
MOSQUITTO_SSL_DIR="/volume2/docker/hass/mosquitto/config"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

if [ ! -f "$ENV_FILE" ]; then
	error "$ENV_FILE file not found"
	exit 1
fi

while IFS='=' read -r key value; do
	[ -z "$key" ] && continue

	case "$key" in
	\#*) continue ;;
	esac

	export "$key=$value"
done <"$ENV_FILE"

if [ -z "${AUTHORIZATION_TOKEN:-}" ]; then
	error "AUTHORIZATION_TOKEN not set in $ENV_FILE"
	exit 1
fi

for file in fullchain.cer ebi.nu.key; do
	if [ ! -f "$CERT_SOURCE/$file" ]; then
		error "Required certificate file not found: $CERT_SOURCE/$file"
		exit 1
	fi
done

log "Updating Home Assistant certificate"

rm -f \
	"$HASS_SSL_DIR/fullchain.cer" \
	"$HASS_SSL_DIR/ebi.nu.key"

cp "$CERT_SOURCE/fullchain.cer" \
	"$HASS_SSL_DIR/fullchain.cer"

cp "$CERT_SOURCE/ebi.nu.key" \
	"$HASS_SSL_DIR/ebi.nu.key"

chmod 0644 "$HASS_SSL_DIR/"*

log "Reloading Home Assistant core configuration"

curl \
	--fail-with-body \
	--silent \
	--show-error \
	--insecure \
	--request POST \
	--header "Authorization: Bearer $AUTHORIZATION_TOKEN" \
	--header "Content-Type: application/json" \
	--data '{}' \
	"https://hass.ebi.nu/api/services/homeassistant/reload_core_config"

printf '\n'

log "Updating Mosquitto certificate"

rm -f \
	"$MOSQUITTO_SSL_DIR/fullchain.pem" \
	"$MOSQUITTO_SSL_DIR/privkey.pem"

cp "$CERT_SOURCE/fullchain.cer" \
	"$MOSQUITTO_SSL_DIR/fullchain.pem"

cp "$CERT_SOURCE/ebi.nu.key" \
	"$MOSQUITTO_SSL_DIR/privkey.pem"

chmod 0644 "$MOSQUITTO_SSL_DIR/"*.pem
chown 1883:1883 "$MOSQUITTO_SSL_DIR/"*.pem

log "Home Assistant and Mosquitto certificate update completed successfully"
