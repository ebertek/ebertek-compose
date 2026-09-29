#!/bin/bash

set -euo pipefail

readonly FROM="/volume2/docker"
readonly TO="/volume2/docker/ebertek-compose-secrets/_persistent"

files=(
	"acmesh/account.conf"
	"bazarr/config/config.yaml"
	"beets/config.yaml"
	"birdnet/config/config.yaml"
	"bjornify/secrets/spotipy_token.cache"
	"calibre-web/.key"
	"calibre-web/client_secrets.json"
	"dbeaver/GlobalConfiguration/.dbeaver/credentials-config.json"
	"dbeaver/GlobalConfiguration/.dbeaver/data-sources.json"
	"dbeaver/GlobalConfiguration/.dbeaver/project-settings.json"
	"gramps/secret/secret"
	"hass/config/automations.yaml"
	"hass/config/configuration.yaml"
	"hass/config/known_devices.yaml"
	"hass/config/scenes.yaml"
	"hass/config/scripts.yaml"
	"hass/config/secrets.yaml"
	"hass/config/ps5-mqtt/credentials.json"
	"hass/config/zigbee2mqtt/configuration.yaml"
	"hass/config/zigbee2mqtt/database.db"
	"hass/config/.storage/core.config"
	"hass/config/.storage/lovelace.dashboard_floorplan"
	"hass/config/.storage/lovelace.dashboard_lights"
	"hass/config/.storage/lovelace.dashboard_pilegarden"
	"hass/esphome/secrets.yaml"
	"hass/frigate/config.yaml"
	"hass/frigate/go2rtc_homekit.yml"
	"hass/influxdb/config/influx-configs"
	"hass/mass/settings.json"
	"hass/mass/webrtc_certificate.pem"
	"hass/mass/webrtc_private_key.pem"
	"hass/matter-server/2031692109443322551.json"
	"hass/matter-server/9371465021952199498.json"
	"hass/matter-server/chip.json"
	"hass/matter-server/chip_factory.ini"
	"hass/matter-server/certificates/driver.json"
	"hass/matter-server/config/driver.json"
	"hass/matter-server/config/snapshot.json.gz"
	"hass/mosquitto/config/mosquitto.conf"
	"hass/mosquitto/config/password.txt"
	"hass/ps5-mqtt/credentials.json"
	"hass/ps5-mqtt/options.json"
	"hass/zigbee2mqtt/configuration.yaml"
	"hass/zigbee2mqtt/database.db"
	"irc/config.js"
	"irc/vapid.json"
	"irc/users/cocakukk.json"
	"keycloak/providers/keystore.p12"
	"keycloak/providers/truststore.p12"
	"lidarr/config.xml"
	"lidarr/asp/key-8ec96f32-657e-4d37-85e2-8829186172f0.xml"
	"prowlarr/config.xml"
	"prowlarr/asp/key-74ab6d65-9c3f-4afd-9313-b6ed3cd35bf2.xml"
	"qbittorrent/mousehole/state.json"
	"qbittorrent/qBittorrent/config/categories.json"
	"qbittorrent/qBittorrent/config/qBittorrent-data.conf"
	"qbittorrent/qBittorrent/config/qBittorrent.conf"
	"qbittorrent/qBittorrent/config/watched_folders.json"
	"radarr/config.xml"
	"radarr/asp/key-ad3c78a0-bc34-40de-92eb-8bb3c0f32097.xml"
	"recyclarr/recyclarr.yml"
	"recyclarr/settings.yml"
	"requestrr/settings.json"
	"smtp/client_sasl_passwd"
	"smtp/data/sasldb2"
	"sonarr/config.xml"
	"sonarr/asp/key-85a4e5b9-6a3e-4ced-8524-e6595f6e186f.xml"
	"tmm/data/data/movies.json"
	"tmm/data/data/tmm.json"
	"tmm/data/data/tmm.lic"
	"tmm/data/data/tvShows.json"
	"tmm/data/data/scraper_fanarttv_movie_artwork.conf"
	"tmm/data/data/scraper_imdb_movie.conf"
	"tmm/data/data/scraper_tmdb_movie.conf"
	"tmm/data/data/scraper_tmdb_movie_artwork.conf"
	"tmm/data/data/scraper_tmdb_movie_trailer.conf"
	"tmm/data/data/scraper_tmdb_tvshow.conf"
	"tmm/data/data/scraper_tmdb_tvshow_artwork.conf"
	"tmm/data/data/scraper_tmdb_tvshow_trailer.conf"
	"tmm/data/data/scraper_tvdb_movie_artwork.conf"
	"tmm/data/data/scraper_tvdb_tvshow.conf"
	"tmm/data/data/scraper_tvdb_tvshow_artwork.conf"
	"traefik/dynamic.yml"
	"vonage-ha-bridge/secrets/vonage_private.key"
	"vw/rsa_key.pem"
	"vw/rsa_key.pub.pem"
)

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

warn() {
	printf '[%s] WARNING: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

main() {
	local missing=0
	local copied=0
	local file src dst

	log "Starting persistent file pull"

	for file in "${files[@]}"; do
		src="${FROM}/${file}"
		dst="${TO}/${file}"

		mkdir -p "$(dirname "$dst")"

		if [[ -f "$src" ]]; then
			cp -f "$src" "$dst"
			((copied += 1))
		else
			warn "Missing source file: $src"
			((missing += 1))
		fi
	done

	log "Copied ${copied} files"

	if ((missing > 0)); then
		warn "${missing} source files were missing"
		return 1
	fi

	log "Persistent file pull completed successfully"
}

main "$@"
