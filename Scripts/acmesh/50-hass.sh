#!/bin/sh
set -e
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_NAME%.sh}.txt"
[ -f "$ENV_FILE" ] || {
	echo "Error: $ENV_FILE file not found!"
	exit 1
}
export "$(grep -v '^#' "$ENV_FILE" | xargs)"

rm /volume1/docker/hass/config/ssl/fullchain.cer
rm /volume1/docker/hass/config/ssl/tnt.photo.key
cp /volume1/docker/acmesh/tnt.photo_ecc/fullchain.cer /volume1/docker/hass/config/ssl/fullchain.cer
cp /volume1/docker/acmesh/tnt.photo_ecc/tnt.photo.key /volume1/docker/hass/config/ssl/tnt.photo.key
chmod 644 /volume1/docker/hass/config/ssl/*
curl -X POST \
	-H "Authorization: Bearer $AUTHORIZATION_TOKEN" \
	-H "Content-Type: application/json" \
	-d '{}' \
	"https://hass.int.tnt.photo/api/services/homeassistant/reload_core_config"

rm /volume1/docker/hass/mosquitto/config/fullchain.pem
rm /volume1/docker/hass/mosquitto/config/privkey.pem
cp /volume1/docker/acmesh/tnt.photo_ecc/fullchain.cer /volume1/docker/hass/mosquitto/config/fullchain.pem
cp /volume1/docker/acmesh/tnt.photo_ecc/tnt.photo.key /volume1/docker/hass/mosquitto/config/privkey.pem
chmod 644 /volume1/docker/hass/mosquitto/config/*.pem
chown 1883:1883 /volume1/docker/hass/mosquitto/config/*.pem
