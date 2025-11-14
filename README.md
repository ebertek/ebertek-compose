# ebertek-compose

A collection of Docker Compose files and shell scripts.

## Docker Compose

### [ebertek/](ebertek/)

- **[bind9](https://hub.docker.com/r/ubuntu/bind9)**: DNS management.
- **[watchtower](https://hub.docker.com/r/nickfedor/watchtower)**: Automatic Docker container image updates.

### [tntphoto/](tntphoto/)

- **[mariadb](https://hub.docker.com/_/mariadb)**: Relational database for WordPress.
- **[wordpress](https://hub.docker.com/_/wordpress)**: Content management system.
- **[nginx](https://hub.docker.com/_/nginx)**: Reverse proxy server for WordPress.

### [ygg/](ygg/)

- **[macvlan](https://docs.docker.com/engine/network/drivers/macvlan/)**: Creates the Macvlan network used by all `ygg-*` Compose files.
- **[watchtower](https://hub.docker.com/r/nickfedor/watchtower)**: Automatic Docker container image updates.

### [ygg-arr/](ygg-arr/)

- **[pg](https://hub.docker.com/_/postgres)**: Object-relational database sytem for \*arr.
- **[prowlarr](https://hotio.dev/containers/prowlarr/)**: Indexer manager for \*arr.
- **[radarr](https://hotio.dev/containers/radarr/)**: Movie organizer/manager.
- **[sonarr](https://hotio.dev/containers/sonarr/)**: Smart PVR.
- **[bazarr](https://hotio.dev/containers/bazarr/)**: Subtitle manager for Sonarr/Radarr.
- **[lidarr](https://hotio.dev/containers/lidarr/)**: Music collection manager.
- **[requestrr](https://hotio.dev/containers/requestrr/)**: Discord chatbot for \*arr.
- **[recyclarr](https://github.com/recyclarr/recyclarr)**: Automatically sync [TRaSH Guides](https://trash-guides.info) to your Sonarr/Radarr instances.

### [ygg-core/](ygg-core/)

- **[cloudflared](https://hub.docker.com/r/cloudflare/cloudflared)**: Client for Cloudflare Tunnel.
- **[dns](https://hub.docker.com/r/technitium/dns-server)**: Technitium DNS Server.
- **[traefik](https://hub.docker.com/_/traefik)**: HTTP reverse proxy.

### [ygg-download/](ygg-download/)

- **[gluetun](https://hub.docker.com/r/qmcgaw/gluetun)**: VPN client.
- **[download](https://docs.linuxserver.io/images/docker-qbittorrent/)**: BitTorrent client.

### [ygg-hass/](ygg-hass/)

- **[matter-server](https://github.com/home-assistant-libs/python-matter-server)**: Matter Controller Server.
- **[mosquitto](https://hub.docker.com/_/eclipse-mosquitto)**: Message broker.
- **[ps5-mqtt](https://github.com/FunkeyFlo/ps5-mqtt)**: PlayStation 5 status integration using MQTT.
- **[zigbee2mqtt](https://hub.docker.com/r/koenkk/zigbee2mqtt/)**: Zigbee to MQTT bridge.
- **[hass](https://github.com/home-assistant/core)**: Home automation.
- **[esphome](https://github.com/esphome/esphome)**: Control ESP32 devices.
  - **[esp-1](_persistent/hass/esphome/esp-1.yaml)**: Espressif ESP32-S3-BOX-3
  - **[esp-2](_persistent/hass/esphome/esp-2.yaml)**: Espressif ESP32-S3-DevKitC-1-N32R8V + Microphone Unit
  - **[esp-3](_persistent/hass/esphome/esp-3.yaml)**: M5Stack AtomS3 Lite ESP32S3 Dev Kit + Light Unit
  - **[esp-4](_persistent/hass/esphome/esp-4.yaml)**: M5Stack AtomS3 Lite ESP32S3 Dev Kit + AtomPortABC + ENVIV Unit (SHT40/BMP280) + PA.HUB 2 Unit + Mini TVOC/eCO2 Ga Unit
  - **[esp-5](_persistent/hass/esphome/esp-5.yaml)**: M5Stack NanoC6 ESP32-C6FH4 Dev Kit + Earth Unit
  - **[esp-6](_persistent/hass/esphome/esp-6.yaml)**: M5Stack NanoC6 ESP32-C6FH4 Dev Kit + Earth Unit

### [ygg-home/](ygg-home/)

- **[plex](https://hub.docker.com/r/plexinc/pms-docker/)**: Media server.
- **[tautulli](https://github.com/Tautulli/Tautulli)**: Monitoring and tracking tool for Plex.
- **[bjornify](https://github.com/ebertek/bjornify)**: Discord bot based on discord.py that adds requested tracks to your Spotify playback queue.
- **[tmm](https://hub.docker.com/r/tinymediamanager/tinymediamanager)**: Media management tool.
- **[books](https://docs.linuxserver.io/images/docker-calibre-web/)**: Web app for browsing, reading and downloading eBooks.

### [ygg-immich/](ygg-immich/)

- **[immich](https://github.com/immich-app/immich)**: Photo and video management.
- **[immich-machine-learning](https://github.com/immich-app/immich/tree/main/machine-learning)**: CLIP embeddings and facial recognition for Immich.
- **[redis](https://hub.docker.com/r/valkey/valkey/)**: Data structure server for Immich.
- **[database](https://github.com/immich-app/base-images/pkgs/container/postgres)**: Scalable vector search in Postgres for Immich.

### [ygg-mon/](ygg-mon/)

- **[loki](https://hub.docker.com/r/grafana/loki)**: Cloud Native Log Aggregation.
- **[alloy](https://hub.docker.com/r/grafana/alloy)**: Vendor-agnostic OpenTelemetry Collector distribution with programmable pipelines.
- **[grafana](https://hub.docker.com/r/grafana/grafana)**: Analytics & monitoring solution.
- **[prometheus](https://hub.docker.com/r/prom/prometheus)**: Systems and service monitoring system.

### [ygg-other/](ygg-other/)

- **[irc](https://github.com/thelounge/thelounge-docker)**: Web IRC client.
- **[vw](https://hub.docker.com/r/vaultwarden/server)**: Password management service.
- **[acmesh](https://hub.docker.com/r/neilpang/acme.sh)**: [ACME client](https://github.com/acmesh-official/acme.sh) for Let's Encrypt certificates.
- **[smtp](https://hub.docker.com/r/turgon37/smtp-relay)**: Postfix SMTP server configured as an SMTP relay.
- **[dbeaver](https://hub.docker.com/r/dbeaver/cloudbeaver)**: Cloud database manager.

## Scripts

### [Scripts/](Scripts/)

- **pull_persistent**: Pull persistent files that should be version tracked.
- **thang010146**: Back up videos from [Nguyen Duc Thang](https://www.youtube.com/user/thang010146).
- **update-matter**: Fix routing between _matter_server_ and Matter devices.

### [acmesh/](Scripts/acmesh/)

- **10-acmesh**: Renew all certificates.
- **20-plex**: Replace _plex_ certificate.
- **30-vpc**: Replace _tntphoto_ certificates.
- **40-syno**: Replace Synology certificates.
- **50-hass**: Replace _hass_ certificates.

### [backup/](Scripts/backup/)

- **hc-sync**: Back up persistent storage from _tntphoto_.
- **photo-sync**: Back up photos.
- **ygg-sync**: Back up persistent storage from NAS.

### [startup/](Scripts/startup/)

- **00-startup**: Load all other scripts.
- **10-fix-sysctl**: Allow memory overcommit, increase the maximum number of incoming connections, fix networking for Docker, increase file system watch limit, [update Docker](<(https://github.com/markdumay/synology-docker)>), [update Synology compatible drive database](https://github.com/007revad/Synology_HDD_db).
- **20-insmod-tun**: Load the `tun` kernel module required for VPN.
- **30-macvlan**: Fix routing between the host and the Macvlan network used by _ygg_.
- **40-disable-active_insight**: Remove Synology Active Insight.
- **50-sdp**: Active current IP for [Smart DNS Proxy](https://www.smartdnsproxy.com/services/).
- **60-rclone**: Update [rclone](https://rclone.org).
- **70-youtube**: Update [yt-dlp](https://github.com/yt-dlp/yt-dlp).

## Requirements

- Docker and Docker Compose.
  - Synology's Container Manager contains an old version of Docker; the [synology-docker](https://github.com/markdumay/synology-docker) script can be used to update it.
- Some folders require specific environment files.

## Usage

1. Update the following elements in `compose.yaml` to work with your environment:
   - `dns`
   - `dns_search`
   - `environment`
   - `extra_hosts`
   - `mac_address`
   - `networks`
   - `user`
   - `volumes`
2. Update the `.txt` files with your own secrets.
3. Deploy:

   ```sh
   cd <folder-name>
   docker compose up -d
   ```
