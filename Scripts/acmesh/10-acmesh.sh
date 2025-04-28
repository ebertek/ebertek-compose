#!/bin/sh
set -e
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_NAME%.sh}.txt"
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "Error: $ENV_FILE file not found!"
  exit 1
fi

docker exec acmesh --issue -d tnt.photo -d '*.tnt.photo' -d '*.int.tnt.photo' -d '*.ext.tnt.photo' --challenge-alias 'tnt.photo' --server letsencrypt --dns dns_cf --force
docker exec acmesh --issue -d melindaban.com -d '*.melindaban.com' --server letsencrypt --dns dns_cf --force
docker exec acmesh --issue -d ebertek.com -d '*.ebertek.com' --server letsencrypt --dns dns_cf --force
docker exec acmesh --issue -d ld25.se -d '*.ld25.se' -d lindi-david.se -d '*.lindi-david.se' --server letsencrypt --dns dns_cf --force
docker exec acmesh --toPkcs -d tnt.photo --password "$PASSWORD"
