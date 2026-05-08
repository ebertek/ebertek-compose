# ebertek-compose

A collection of Docker Compose files and shell scripts.

## Overview

This repository contains self-hosted infrastructure and home automation services using Docker Compose.

Main areas:

- Home automation (Home Assistant, ESPHome, Zigbee2MQTT, Matter)
- Media management and streaming (\*arr stack, Plex, Immich)
- Monitoring (Grafana, Loki, Prometheus, Alloy)
- Identity and networking (Keycloak, Traefik, Cloudflare Tunnel)
- Utility services and maintenance scripts

## Docker Compose

### [ebertek/](ebertek/)

- **[alloy](https://hub.docker.com/r/grafana/alloy)**: Collect and forward logs and metrics to `ygg-mon`.
- **[bind9](https://hub.docker.com/r/ubuntu/bind9)**: DNS management.
- **[watchtower](https://hub.docker.com/r/nickfedor/watchtower)**: Automatic Docker container image updates.

### [tntphoto/](tntphoto/)

- **[mariadb](https://hub.docker.com/_/mariadb)**: Relational database for WordPress.
- **[nginx](https://hub.docker.com/_/nginx)**: Reverse proxy server for WordPress.
- **[wordpress](https://hub.docker.com/_/wordpress)**: Content management system.

### [ygg/](ygg/)

- **[macvlan](https://docs.docker.com/engine/network/drivers/macvlan/)**: Creates the Docker Macvlan network shared by all `ygg-*` Compose projects.
- **[watchtower](https://hub.docker.com/r/nickfedor/watchtower)**: Automatic Docker container image updates.

### [ygg-arr/](ygg-arr/)

- **[bazarr](https://hotio.dev/containers/bazarr/)**: Subtitle manager for Sonarr/Radarr.
- **[lidarr](https://hotio.dev/containers/lidarr/)**: Music collection manager.
- **[pg](https://hub.docker.com/_/postgres)**: Object-relational database system for \*arr.
- **[prowlarr](https://hotio.dev/containers/prowlarr/)**: Indexer manager for \*arr.
- **[radarr](https://hotio.dev/containers/radarr/)**: Movie organizer/manager.
- **[recyclarr](https://github.com/recyclarr/recyclarr)**: Automatically sync [TRaSH Guides](https://trash-guides.info) to your Sonarr/Radarr instances.
- **[requestrr](https://hotio.dev/containers/requestrr/)**: Discord chatbot for \*arr.
- **[sonarr](https://hotio.dev/containers/sonarr/)**: Smart PVR.
- **[unpackerr](https://github.com/Unpackerr/unpackerr)**: Extracts downloads for Radarr, Sonarr, Lidarr, Readarr, and/or a Watch folder.

### [ygg-birdnet/](ygg-birdnet/)

- **[birdnet](https://github.com/tphakala/birdnet-go)**: AI solution for continuous avian monitoring and identification.

### [ygg-core/](ygg-core/)

- **[cloudflare-ddns](https://github.com/favonia/cloudflare-ddns)**: A small, feature-rich, and robust Cloudflare DDNS updater.
- **[cloudflared](https://hub.docker.com/r/cloudflare/cloudflared)**: Client for Cloudflare Tunnel.
- **[dns](https://hub.docker.com/r/technitium/dns-server)**: Technitium DNS Server.
- **[keycloak](https://github.com/keycloak/keycloak)**: Open Source Identity and Access Management.
- **[oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy)**: A reverse proxy that provides authentication with OpenID Connect.
- **[postgres](https://github.com/docker-library/postgres)**: Object-relational database system for Keycloak.
- **[traefik](https://hub.docker.com/_/traefik)**: HTTP reverse proxy.

### [ygg-download/](ygg-download/)

- **[download](https://github.com/qbittorrent/docker-qbittorrent-nox)**: BitTorrent client.
- **[gluetun](https://hub.docker.com/r/qmcgaw/gluetun)**: VPN client.
- **[mousehole](https://github.com/t-mart/mousehole)**: A background service to update a seedbox IP for MAM.

### [ygg-hass/](ygg-hass/)

- **[esphome](https://github.com/esphome/esphome)**: Control ESP32 devices.
  - **[esp-bedroom-1](_persistent/hass/esphome/esp-bedroom-1.yaml)**: M5Stack AtomS3 Lite ESP32S3 Dev Kit + AtomPortABC + ENVIV Unit (SHT40/BMP280) + PA.HUB 2 Unit + Mini TVOC/eCO2 Ga Unit
  - **[esp-guest-1](_persistent/hass/esphome/esp-guest-1.yaml)**: Espressif ESP32-S3-DevKitC-1-N32R8V + Microphone Unit
  - **[esp-hall-1](_persistent/hass/esphome/esp-hall-1.yaml)**: M5Stack AtomS3 Lite ESP32S3 Dev Kit + Light Unit
  - **[esp-kitchen-1](_persistent/hass/esphome/esp-kitchen-1.yaml)**: M5Stack NanoC6 ESP32-C6FH4 Dev Kit + Earth Unit
  - **[esp-kitchen-2](_persistent/hass/esphome/esp-kitchen-2.yaml)**: M5Stack NanoC6 ESP32-C6FH4 Dev Kit + Earth Unit
  - **[esp-office-1](_persistent/hass/esphome/esp-office-1.yaml)**: Espressif ESP32-S3-BOX-3
  - **[lora-1](_persistent/hass/lora/lora-1/lora-1.ino)**: Heltec WiFi LoRa 32(V3) home receiver node that bridges LoRa mailbox events to MQTT/Home Assistant
  - **[lora-2](_persistent/hass/lora/lora-2/lora-2.ino)**: Battery-powered Heltec WiFi LoRa 32(V3) remote mailbox sensor using an MC-38 reed switch
- **[hass](https://github.com/home-assistant/core)**: Home automation.
- **[influxdb](https://github.com/influxdata/influxdb/tree/main-2.x)**: Time series database built for real-time analytic workloads.
- **[matter-server](https://github.com/matter-js/matterjs-server)**: Matter server based on Matter.js.
- **[mosquitto](https://hub.docker.com/_/eclipse-mosquitto)**: Message broker.
- **[ps5-mqtt](https://github.com/FunkeyFlo/ps5-mqtt)**: PlayStation 5 status integration using MQTT.
- **[scrypted](https://github.com/koush/scrypted)**: High performance video integration and automation platform.
- **[vonage](https://github.com/ebertek/vonage-ha-bridge)**: Vonage to Home Assistant bridge for SMS and voice.
- **[zigbee2mqtt](https://hub.docker.com/r/koenkk/zigbee2mqtt/)**: Zigbee to MQTT bridge.

### [ygg-home/](ygg-home/)

- **[bjornify](https://github.com/ebertek/bjornify)**: Discord bot based on discord.py that adds requested tracks to your Spotify playback queue.
- **[books](https://docs.linuxserver.io/images/docker-calibre-web/)**: Web app for browsing, reading and downloading eBooks.
- **[plex](https://hub.docker.com/r/plexinc/pms-docker/)**: Media server.
- **[tautulli](https://github.com/Tautulli/Tautulli)**: Monitoring and tracking tool for Plex.
- **[tmm](https://hub.docker.com/r/tinymediamanager/tinymediamanager)**: Media management tool.

### [ygg-immich/](ygg-immich/)

- **[database](https://github.com/immich-app/base-images/pkgs/container/postgres)**: Scalable vector search in Postgres for Immich.
- **[immich](https://github.com/immich-app/immich)**: Photo and video management.
- **[immich-machine-learning](https://github.com/immich-app/immich/tree/main/machine-learning)**: CLIP embeddings and facial recognition for Immich.
- **[redis](https://hub.docker.com/r/valkey/valkey/)**: Data structure server for Immich.

### [ygg-mon/](ygg-mon/)

- **[alloy](https://hub.docker.com/r/grafana/alloy)**: Vendor-agnostic OpenTelemetry Collector distribution with programmable pipelines.
- **[grafana](https://hub.docker.com/r/grafana/grafana)**: Analytics & monitoring solution.
- **[loki](https://hub.docker.com/r/grafana/loki)**: Cloud Native Log Aggregation.
- **[prometheus](https://hub.docker.com/r/prom/prometheus)**: Systems and service monitoring system.

### [ygg-other/](ygg-other/)

- **[acmesh](https://hub.docker.com/r/neilpang/acme.sh)**: [ACME client](https://github.com/acmesh-official/acme.sh) for Let's Encrypt certificates.
- **[dbeaver](https://hub.docker.com/r/dbeaver/cloudbeaver)**: Cloud database manager.
- **[irc](https://github.com/thelounge/thelounge-docker)**: Web IRC client.
- **[smtp](https://hub.docker.com/r/turgon37/smtp-relay)**: Postfix SMTP server configured as an SMTP relay.
- **[vw](https://hub.docker.com/r/vaultwarden/server)**: Password management service.

## Scripts

### [Scripts/](Scripts/)

- **pull_persistent**: Pull persistent files that should be version-controlled.
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

- **00-startup**: Load all other scripts, [update Docker](<(https://github.com/markdumay/synology-docker)>), [update Synology compatible drive database](https://github.com/007revad/Synology_HDD_db).
- **10-fix-sysctl**: Applies kernel/sysctl tuning for containerized workloads and networking, including increased inotify watcher limits, higher socket backlog capacity, IPv4/IPv6 networking adjustments, unprivileged ICMP ping support, and Redis-compatible memory overcommit settings.
- **20-insmod-tun**: Load the `tun` kernel module required for VPN.
- **30-macvlan**: Fix routing between the host and the Macvlan network used by _ygg_.
- **40-disable-active_insight**: Remove Synology Active Insight.
- **50-sdp**: Activate current IP for [Smart DNS Proxy](https://www.smartdnsproxy.com/services/).
- **60-rclone**: Update [rclone](https://rclone.org).
- **70-youtube**: Update [yt-dlp](https://github.com/yt-dlp/yt-dlp).

## Requirements

- Docker and Docker Compose.
  - Synology's Container Manager contains an old version of Docker; the [synology-docker](https://github.com/markdumay/synology-docker) script can be used to update it.
  - Some older Synology DSM/kernel versions may require the legacy [yggdrasil-final](../../tree/yggdrasil-final) branch.
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
