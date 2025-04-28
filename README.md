# ebertek-compose
A collection of Docker Compose files for various self-hosted services.

## Services

### [ebertek/](ebertek/)
- **[bind9](https://hub.docker.com/r/ubuntu/bind9)**: DNS management.
- **[watchtower](https://hub.docker.com/r/containrrr/watchtower)**: Automatic Docker container base image updates.

### [tntphoto/](tntphoto/)
- **[mariadb](https://hub.docker.com/_/mariadb)**: Relational database for WordPress.
- **[wordpress](https://hub.docker.com/_/wordpress)**: Content management system.
- **[nginx](https://hub.docker.com/_/nginx)**: Reverse proxy server for WordPress.

### [ygg/](ygg/)
- **[macvlan](https://docs.docker.com/engine/network/drivers/macvlan/)**: Creates the Macvlan network used by all `ygg-*` Compose files.
- **[watchtower](https://hub.docker.com/r/containrrr/watchtower)**: Automatic Docker container base image updates.

### [ygg-arr/](ygg-arr/)
- **[pg](https://hub.docker.com/_/postgres)**: Object-relational database sytem for *arr.
- **[prowlarr](https://hotio.dev/containers/prowlarr/)**: Indexer manager for *arr.
- **[radarr](https://hotio.dev/containers/radarr/)**: Movie organizer/manager.
- **[sonarr](https://hotio.dev/containers/sonarr/)**: Smart PVR.
- **[bazarr](https://hotio.dev/containers/bazarr/)**: Subtitle manager for Sonarr/Radarr.
- **[lidarr](https://hotio.dev/containers/lidarr/)**: Music collection manager.
- **[requestrr](https://hotio.dev/containers/requestrr/)**: Discord chatbot for *arr.
- **[recyclarr](https://github.com/recyclarr/recyclarr)**: Automatically sync [TRaSH Guides](https://trash-guides.info) to your Sonarr/Radarr instances.

### [ygg-core/](ygg-core/)
- **[omada](https://hub.docker.com/r/mbentley/omada-controller)**: TP-Link Omada controller.
- **[cloudflared](https://hub.docker.com/r/cloudflare/cloudflared)**: Client for Cloudflare Tunnel.
- **[dns](https://hub.docker.com/r/technitium/dns-server)**: Technitium DNS Server.
- **[npm](https://hub.docker.com/r/jc21/nginx-proxy-manager)**: Reverse proxy.

### [ygg-download/](ygg-download/)
- **[gluetun](https://hub.docker.com/r/qmcgaw/gluetun)**: VPN client.
- **[download](https://docs.linuxserver.io/images/docker-qbittorrent/)**: BitTorrent client.

### [ygg-hass/](ygg-hass/)
- **[matter-server](https://github.com/home-assistant-libs/python-matter-server)**: Matter Controller Server.
- **[mosquitto](https://hub.docker.com/_/eclipse-mosquitto)**: Message broker.
- **[ps5-mqtt](https://github.com/FunkeyFlo/ps5-mqtt)**: PlayStation 5 status integration using MQTT.
- **[zigbee2mqtt](https://hub.docker.com/r/koenkk/zigbee2mqtt/)**: Zigbee to MQTT bridge.
- **[hass](https://github.com/home-assistant/core)**: Home automation.
- **[esphome](https://github.com/esphome/esphome)**: Control ESP32 through Home Assistant.

### [ygg-home/](ygg-home/)
- **[plex](https://hub.docker.com/r/plexinc/pms-docker/)**: Media server.
- **[tautulli](https://github.com/Tautulli/Tautulli)**: Monitoring and tracking tool for Plex.
- **[discordpy](https://hub.docker.com/r/gorialis/discord.py)**: Bot-ready environments for Python bots. Includes two bots: **hass** and **bjornify**.
- **[tmm](https://hub.docker.com/r/tinymediamanager/tinymediamanager)**: Media management tool.
- **[books](https://docs.linuxserver.io/images/docker-calibre-web/)**: Web app for browsing, reading and downloading eBooks.

### [ygg-immich/](ygg-immich/)
- **[immich](https://github.com/immich-app/immich)**: Photo and video management.
- **[immich-machine-learning](https://github.com/immich-app/immich/tree/main/machine-learning)**: CLIP embeddings and facial recognition for Immich.
- **[redis](https://hub.docker.com/r/valkey/valkey/)**: Data structure server for Immich.
- **[database](https://hub.docker.com/r/tensorchord/pgvecto-rs)**: Scalable vector search in Postgres for Immich.

### [ygg-other/](ygg-other/)
- **[irc](https://github.com/thelounge/thelounge-docker)**: Web IRC client.
- **[vw](https://hub.docker.com/r/vaultwarden/server)**: Password management service.
- **[acmesh](https://hub.docker.com/r/neilpang/acme.sh)**: [ACME client](https://github.com/acmesh-official/acme.sh) for Let's Encrypt certificates.
- **[smtp](https://hub.docker.com/r/turgon37/smtp-relay)**: Postfix SMTP server configured as an SMTP relay.
- **[dbeaver](https://hub.docker.com/r/dbeaver/cloudbeaver)**: Cloud database manager.

## Requirements
- Docker.
- Docker Compose.
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

    ```
    cd <folder-name>
    docker compose up -d
    ```
