#!/bin/sh
set -e
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_NAME%.sh}.txt"
[ -f "$ENV_FILE" ] || { echo "Error: $ENV_FILE file not found!"; exit 1; }
export "$(grep -v '^#' "$ENV_FILE" | xargs)"

scp -r -P "$PORT" -i /var/services/homes/Hannibal/.ssh/id_rsa /volume1/docker/acmesh "$USER"@"$HOST":~/
ssh "$HOST" -i /var/services/homes/Hannibal/.ssh/id_rsa -l "$USER" -p "$PORT" << EOF
  sudo -s
  rm -r /mnt/data/tntphoto_certbot_config/_data/archive/*
  cp -R /root/acmesh/* /mnt/data/tntphoto_certbot_config/_data/archive/
  rm -r /root/acmesh
  mv /mnt/data/tntphoto_certbot_config/_data/archive/ebertek.com_ecc /mnt/data/tntphoto_certbot_config/_data/archive/ebertek.com
  mv /mnt/data/tntphoto_certbot_config/_data/archive/melindaban.com_ecc /mnt/data/tntphoto_certbot_config/_data/archive/melindaban.com
  mv /mnt/data/tntphoto_certbot_config/_data/archive/tnt.photo_ecc /mnt/data/tntphoto_certbot_config/_data/archive/tnt.photo
  mv /mnt/data/tntphoto_certbot_config/_data/archive/ld25.se_ecc /mnt/data/tntphoto_certbot_config/_data/archive/ld25.se
  chmod 644 /mnt/data/tntphoto_certbot_config/_data/archive/ebertek.com/*
  chmod 644 /mnt/data/tntphoto_certbot_config/_data/archive/melindaban.com/*
  chmod 644 /mnt/data/tntphoto_certbot_config/_data/archive/tnt.photo/*
  chmod 644 /mnt/data/tntphoto_certbot_config/_data/archive/ld25.se/*
  chmod 600 /mnt/data/tntphoto_certbot_config/_data/archive/ebertek.com/ebertek.com.key
  chmod 600 /mnt/data/tntphoto_certbot_config/_data/archive/melindaban.com/melindaban.com.key
  chmod 600 /mnt/data/tntphoto_certbot_config/_data/archive/tnt.photo/tnt.photo.key
  chmod 600 /mnt/data/tntphoto_certbot_config/_data/archive/ld25.se/ld25.se.key
  chown -R 101:101 /mnt/data/tntphoto_certbot_config/_data/archive
  docker exec nginx sh -c "/usr/sbin/nginx -s reload"
EOF
