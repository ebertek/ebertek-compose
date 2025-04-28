# ebertek-compose
A collection of Docker Compose files for various self-hosted services.

## Services

### [ebertek/](ebertek/)
- **bind9**: DNS server.
- **watchtower**: Automatic Docker container updater.

### [tntphoto/](tntphoto/)
- **mariadb**: Database server for WordPress.
- **wordpress**: WordPress application.
- **nginx**: Reverse proxy for WordPress.

### [ygg/](ygg/)
- **watchtower**: Automatic Docker container updater.

### [ygg-arr/](ygg-arr/)
- **pg**: PostgreSQL database service.
- **prowlarr**: Indexer manager for Sonarr/Radarr/etc.
- **radarr**: Movies download and management.
- **sonarr**: TV shows download and management.
- **bazarr**: Subtitle management for Sonarr/Radarr.
- **lidarr**: Music library management.
- **requestrr**: Media request bot (Discord integration).
- **recyclarr**: Sync Sonarr/Radarr settings with maintained lists.

### [ygg-core/](ygg-core/)
- **omada**: TP-Link Omada controller.
- **cloudflared**: Cloudflare Tunnel client.
- **dns**: DNS server.
- **npm**: Reverse proxy.

### [ygg-download/](ygg-download/)
- **gluetun**: VPN client for containerized apps.
- **download**: qBittorrent.

### [ygg-hass/](ygg-hass/)
- **matter-server**: Matter protocol server for smart home.
- **mosquitto**: MQTT broker.
- **ps5-mqtt**: PlayStation 5 status integration via MQTT.
- **zigbee2mqtt**: Zigbee device integration via MQTT.
- **hass**: Home Assistant platform.
- **esphome**: Smart devices management (ESP-based devices).

### [ygg-home/](ygg-home/)
- **plex**: Media server for movies and TV shows.
- **tautulli**: Plex usage statistics and monitoring.
- **discordpy**: Custom Discord bot (Python based).
- **tmm**: TinyMediaManager (media management).
- **books**: Calibre-web ebook management service.

### [ygg-immich/](ygg-immich/)
- **immich**: Self-hosted photo and video backup system.
- **immich-machine-learning**: ML features for Immich.
- **redis**: Cache and message broker for Immich.
- **database**: Database backend for Immich.

### [ygg-other/](ygg-other/)
- **irc**: IRC client.
- **vw**: Vaultwarden password manager.
- **acmesh**: ACME client for Let's Encrypt certificates.
- **smtp**: SMTP email relay service.
- **dbeaver**: Database management UI tool.

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
2. Copy `*.example.txt` to `*.txt` and update its contents with your own secrets.
3. Deploy:

    ```
    cd <folder-name>
    docker compose up -d
    ```
