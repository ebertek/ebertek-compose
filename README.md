# ebertek-compose

A collection of Docker Compose files and shell scripts.

## Overview

This repository contains Docker Compose configuration, persistent application configuration, and supporting scripts for self-hosted infrastructure across multiple hosts.

Main areas:

- Home automation (Home Assistant, ESPHome, Zigbee2MQTT, Matter)
- Media management and streaming (\*arr stack, Plex, Immich)
- Monitoring (Grafana, Loki, Prometheus, Alloy)
- Identity and networking (Keycloak, Traefik, Cloudflare Tunnel, Technitium DNS)
- GitOps and container management (Komodo, Renovate)
- Remote web hosting (WordPress, MariaDB, nginx)
- Utility services, backups, and host startup/maintenance scripts

## Docker Compose

### [ebertek/](ebertek/)

- **[alloy](https://hub.docker.com/r/grafana/alloy)**: Collect and forward logs and metrics to `ygg-mon`.
- **[bind9](https://hub.docker.com/r/ubuntu/bind9)**: DNS management.

### [tntphoto/](tntphoto/)

- **[mariadb](https://hub.docker.com/_/mariadb)**: Relational database for WordPress.
- **[nginx](https://hub.docker.com/_/nginx)**: Reverse proxy server for WordPress.
- **[wordpress](https://hub.docker.com/_/wordpress)**: Custom WordPress (content management system) PHP-FPM image based on `wordpress:php8.3-fpm-alpine`, with additional PHP extensions.

### [ygg/](ygg/)

- **[alloy](https://hub.docker.com/r/grafana/alloy)**: Collect and forward logs and metrics to `ygg-mon`.

### [ygg-arr/](ygg-arr/)

- **[bazarr](https://github.com/hotio/bazarr)**: Subtitle manager for Sonarr/Radarr.
- **[lidarr](https://github.com/hotio/lidarr)**: Music collection manager.
- **[pg-arr](https://hub.docker.com/_/postgres)**: Object-relational database system for \*arr.
- **[prowlarr](https://github.com/hotio/prowlarr)**: Indexer manager for \*arr.
- **[radarr](https://github.com/hotio/radarr)**: Movie organizer/manager.
- **[recyclarr](https://github.com/recyclarr/recyclarr)**: Automatically sync [TRaSH Guides](https://trash-guides.info) to your Sonarr/Radarr instances.
- **[requestrr](https://github.com/hotio/requestrr)**: Discord chatbot for \*arr.
- **[sonarr](https://github.com/hotio/sonarr)**: Smart PVR.
- **[unpackerr](https://hub.docker.com/r/golift/unpackerr)**: Extracts downloads for Radarr, Sonarr, Lidarr, Readarr, and/or a Watch folder.

### [ygg-birdnet/](ygg-birdnet/)

- **[birdnet](https://github.com/tphakala/birdnet-go)**: AI solution for continuous avian monitoring and identification.

### [ygg-core/](ygg-core/)

- **[autoheal](https://hub.docker.com/r/willfarrell/autoheal)**: Monitor and restart unhealthy docker containers.
- **[cloudflare-ddns](https://hub.docker.com/r/favonia/cloudflare-ddns)**: A small, feature-rich, and robust Cloudflare DDNS updater.
- **[cloudflared](https://hub.docker.com/r/cloudflare/cloudflared)**: Client for Cloudflare Tunnel.
- **[dns](https://hub.docker.com/r/technitium/dns-server)**: Technitium DNS Server.
- **[keycloak](https://github.com/keycloak/keycloak)**: Open Source Identity and Access Management.
- **[oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy)**: A reverse proxy that provides authentication with OpenID Connect.
- **[pg-keycloak](https://hub.docker.com/_/postgres)**: Object-relational database system for Keycloak.
- **[traefik](https://hub.docker.com/_/traefik)**: HTTP reverse proxy.

### [ygg-download/](ygg-download/)

- **[download](https://hub.docker.com/r/qbittorrentofficial/qbittorrent-nox)**: BitTorrent client.
- **[gluetun](https://github.com/passteque/gluetun)**: VPN client in a thin Docker container for multiple VPN providers.
- **[mousehole](https://hub.docker.com/r/tmmrtn/mousehole)**: A background service to update a seedbox IP for MAM.

### [ygg-gramps/](ygg-gramps/)

- **[gramps](https://github.com/gramps-project/gramps-web)**: Open Source Online Genealogy System.
- **[grampsweb-celery](https://github.com/gramps-project/gramps-web)**: Distributed Task Queue for Gramps.
- **[rd-gramps](https://hub.docker.com/_/redis)**: Data platform for caching, vector search, and NoSQL databases.

### [ygg-hass/](ygg-hass/)

- **[esphome](https://github.com/esphome/esphome)**: Control ESP32 devices.
  - **[esp-4](_persistent/hass/esphome/esp-4.yaml)**: M5Stack AtomS3 Lite ESP32S3 Dev Kit
    - Atomic Port ABC Base
    - Unit ENV-IV (SHT40 + BMP280)
    - Unit Light (photoresistor + LM393DR2G dual differential comparator)
    - Unit Mini TVOC/eCO2 (SGP30)
    - Unit PaHub v2.0 (PCA9548AP)
    - Unit RF433R (SYN531R)
  - **[esp-2](_persistent/hass/esphome/esp-2.yaml)**: Espressif ESP32-S3-DevKitC-1-N32R8V
    - BME280
    - Unit MIC (MAX4466 microphone preamplifier + LM393DR2G dual-voltage comparator)
  - **[esp-3](_persistent/hass/esphome/esp-3.yaml)**: M5Stack AtomS3 Lite ESP32S3 Dev Kit
  - **[esp-7](_persistent/hass/esphome/esp-7.yaml)**: M5Stack AtomS3 Lite ESP32S3 Dev Kit
    - Atomic Port ABC Base
    - Unit RF433T (SYN115)
  - **[esp-5](_persistent/hass/esphome/esp-5.yaml)**: M5Stack NanoC6 ESP32-C6FH4 Dev Kit
    - Unit KMeter-ISO (STM32F030 data acquisition + MAX31855KASA+T thermocouple digital conversion + CA-IS3641HW signal isolation)
  - **[esp-6](_persistent/hass/esphome/esp-6.yaml)**: M5Stack NanoC6 ESP32-C6FH4 Dev Kit
    - Unit Watering (22 μF capacitor + EDLP600-D12B water pump)
  - **[esp-1](_persistent/hass/esphome/esp-1.yaml)**: Espressif ESP32-S3-BOX-3
    - Audio input: ES7210
    - Audio output: ES8311 + NS4150
    - Gyroscope + accelerometer: ICM-42607-P
    - ESP32-S3-BOX-3-SENSOR
      - Radar: AT581X (MS58-3909S68U4)
      - Infrared: IRM-H638T + IR67-21C/TR8
      - Temperature + humidity: AHT30
  - **[lora-1](_persistent/hass/lora/lora-1/lora-1.ino)**: Heltec WiFi LoRa 32(V3) home receiver node that bridges LoRa mailbox events to MQTT/Home Assistant
  - **[lora-2](_persistent/hass/lora/lora-2/lora-2.ino)**: Battery-powered Heltec WiFi LoRa 32(V3) remote mailbox sensor using an MC-38 reed switch
- **[frigate](https://github.com/blakeblackshear/frigate)**: NVR with realtime local object detection for IP cameras.
- **[hass](https://github.com/home-assistant/core)**: Home automation that puts local control and privacy first.
- **[influxdb](https://github.com/influxdata/influxdb/tree/main-2.x)**: Time series database built for real-time analytic workloads.
- **[mass](https://github.com/music-assistant/server)**: Media library manager that connects to your streaming services and a wide range of connected speakers.
- **[mass-alexa](https://github.com/alams154/music-assistant-alexa-skill-prototype)**: Alexa skill prototype for controlling the Music Assistant server.
- **[matter-server](https://github.com/matter-js/matterjs-server)**: Matter server based on Matter.js.
- **[mosquitto](https://hub.docker.com/_/eclipse-mosquitto)**: Message broker.
- **[ps5-mqtt](https://github.com/FunkeyFlo/ps5-mqtt)**: PlayStation 5 status integration using MQTT.
- **[scrypted](https://github.com/koush/scrypted)**: High performance video integration and automation platform.
- **[vonage](https://github.com/ebertek/vonage-ha-bridge)**: Vonage to Home Assistant bridge for SMS and voice.
- **[zigbee2mqtt](https://hub.docker.com/r/koenkk/zigbee2mqtt/)**: Zigbee to MQTT bridge.

### [ygg-home/](ygg-home/)

- **[bjornify](https://github.com/ebertek/bjornify)**: Discord bot based on discord.py that adds requested tracks to your Spotify playback queue.
- **[books](https://github.com/new-usemame/calibre-web-nextgen)**: Community continuation of Calibre-Web-Automated.
- **[plex](https://hub.docker.com/r/plexinc/pms-docker/)**: Media server.
- **[plextraktsync](https://github.com/Taxel/PlexTraktSync)**: A python script that syncs the movies, shows and ratings between trakt and Plex.
- **[scheduler](https://github.com/mcuadros/ofelia)**: A docker job scheduler.
- **[tautulli](https://github.com/Tautulli/Tautulli)**: Monitoring and tracking tool for Plex.
- **[tmm](https://hub.docker.com/r/tinymediamanager/tinymediamanager)**: Media management tool.

### [ygg-immich/](ygg-immich/)

- **[immich](https://github.com/immich-app/immich)**: Photo and video management.
- **[immich-machine-learning](https://github.com/immich-app/immich/tree/main/machine-learning)**: CLIP embeddings and facial recognition for Immich.
- **[pg-immich](https://github.com/immich-app/base-images/pkgs/container/postgres)**: Scalable vector search in Postgres for Immich.
- **[rd-immich](https://github.com/valkey-io/valkey)**: Data structure server for Immich.

### [ygg-komodo/](ygg-komodo/)

- **[komodo](https://github.com/moghtech/komodo)**: A tool to build and deploy software on many server.
- **[mongo](https://hub.docker.com/_/mongo)**: MongoDB document database used by Komodo.
- **[periphery](https://github.com/moghtech/komodo)**: Komodo agent.

### [ygg-mon/](ygg-mon/)

- **[alloy](https://hub.docker.com/r/grafana/alloy)**: Vendor-agnostic OpenTelemetry Collector distribution with programmable pipelines.
- **[grafana](https://hub.docker.com/r/grafana/grafana)**: Analytics & monitoring solution.
- **[loki](https://hub.docker.com/r/grafana/loki)**: Cloud Native Log Aggregation.
- **[prometheus](https://hub.docker.com/r/prom/prometheus)**: Systems and service monitoring system.

### [ygg-other/](ygg-other/)

- **[acmesh](https://hub.docker.com/r/neilpang/acme.sh)**: [ACME client](https://github.com/acmesh-official/acme.sh) for Let's Encrypt certificates.
- **[atuin](https://github.com/atuinsh/atuin)**: Making your shell magical.
- **[browser](https://docs.linuxserver.io/images/docker-chromium/)**: Web accessible Chromium inside a Debian Container.
- **[dbeaver](https://hub.docker.com/r/dbeaver/cloudbeaver)**: Cloud database manager.
- **[irc](https://github.com/thelounge/thelounge-docker)**: Web IRC client.
- **[pg-atuin](https://hub.docker.com/_/postgres)**: PostgreSQL database used by Atuin.
- **[smtp](https://hub.docker.com/r/turgon37/smtp-relay)**: Postfix SMTP server configured as an SMTP relay.
- **[vw](https://github.com/dani-garcia/vaultwarden)**: Password management service.

## Scripts

### [Scripts/](Scripts/)

- **pull_persistent**: Pull persistent files that should be version-controlled.
- **thang010146**: Back up videos from [Nguyen Duc Thang](https://www.youtube.com/user/thang010146).
- **update-matter**: Fix routing between _matter_server_ and Matter devices.
- **update-nftset**: Update an IP blacklist using nftables sets.

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

- **00-startup**: Run the Synology startup maintenance scripts, including sysctl tuning, TUN setup, Active Insight configuration, Smart DNS Proxy IP activation, rclone updates, yt-dlp/PhantomJS updates, and [Synology HDD database updates](https://github.com/007revad/Synology_HDD_db).
- **10-fix-sysctl**: Apply kernel/sysctl settings required or recommended by containerized workloads and networking, including increased inotify watcher limits, socket backlog capacity, IPv4/IPv6 settings, unprivileged ICMP ping support, and Redis-compatible memory overcommit.
- **20-insmod-tun**: Create `/dev/net/tun` if necessary and load the `tun` kernel module required for VPN networking.
- **30-macvlan-host**: Configure host-side routing for the Docker Macvlan network.
- **31-macvlan-docker**: Configure the Docker Macvlan network.
- **32-ygg-compose**: Manage startup and shutdown of the allowlisted `ygg-*` Docker Compose stacks, with separate handling for NFS-dependent services.
- **40-disable-active_insight**: Disable Synology Active Insight file activity monitoring.
- **50-sdp**: Update the current public IP address with [Smart DNS Proxy](https://www.smartdnsproxy.com/services/).
- **60-rclone**: Update the installed [rclone](https://rclone.org) binary to the latest stable release.
- **70-youtube**: Update [yt-dlp](https://github.com/yt-dlp/yt-dlp) and install/update PhantomJS for tinyMediaManager.

## Requirements

- Linux host with Docker Engine and Docker Compose.
- Git for Git-backed deployment.
- Host-specific external networks, bind-mount paths, and secrets referenced by the relevant Compose stacks.
- NFS mounts are required by selected Pleiades services using the `nfs` Compose profile.

For legacy Synology deployments:

- Synology Container Manager may ship an older Docker version; [synology-docker](https://github.com/markdumay/synology-docker) can be used to update it.
- Older DSM/kernel versions may require the legacy [yggdrasil-final](../../tree/yggdrasil-final) branch.

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
