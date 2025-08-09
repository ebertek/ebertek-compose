#!/bin/sh
set -e
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_DIR}/${SCRIPT_NAME%.sh}.txt"
[ -f "$ENV_FILE" ] || {
	echo "Error: $ENV_FILE file not found!"
	exit 1
}
while IFS='=' read -r key value; do
	[ -z "$key" ] && continue
	case "$key" in
	\#*) continue ;;
	esac
	export "$key=$value"
done <"$ENV_FILE"

rm /volume2/docker/hass/config/ssl/fullchain.cer
rm /volume2/docker/hass/config/ssl/tnt.photo.key
cp /volume2/docker/acmesh/tnt.photo_ecc/fullchain.cer /volume2/docker/hass/config/ssl/fullchain.cer
cp /volume2/docker/acmesh/tnt.photo_ecc/tnt.photo.key /volume2/docker/hass/config/ssl/tnt.photo.key
chmod 644 /volume2/docker/hass/config/ssl/*
curl -k -X POST \
	-H "Authorization: Bearer $AUTHORIZATION_TOKEN" \
	-H "Content-Type: application/json" \
	-d '{}' \
	"https://hass.int.tnt.photo/api/services/homeassistant/reload_core_config"

rm /volume2/docker/hass/mosquitto/config/fullchain.pem
rm /volume2/docker/hass/mosquitto/config/privkey.pem
cp /volume2/docker/acmesh/tnt.photo_ecc/fullchain.cer /volume2/docker/hass/mosquitto/config/fullchain.pem
cp /volume2/docker/acmesh/tnt.photo_ecc/tnt.photo.key /volume2/docker/hass/mosquitto/config/privkey.pem
chmod 644 /volume2/docker/hass/mosquitto/config/*.pem
chown 1883:1883 /volume2/docker/hass/mosquitto/config/*.pem
