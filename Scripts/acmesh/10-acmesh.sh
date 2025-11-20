#!/bin/sh
set -e

ACMESH_CONTAINER=$(docker ps --filter "label=com.docker.compose.service=acmesh" --format '{{.ID}}' | head -n1)
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

docker exec "$ACMESH_CONTAINER" --issue -d ebi.nu -d '*.ebi.nu' -d 'ygg.nu' -d '*.ygg.nu' --server letsencrypt --dns dns_cf --force
docker exec "$ACMESH_CONTAINER" --issue -d tnt.photo -d '*.tnt.photo' -d '*.int.tnt.photo' -d '*.ext.tnt.photo' --challenge-alias 'tnt.photo' --server letsencrypt --dns dns_cf --force
docker exec "$ACMESH_CONTAINER" --issue -d melindaban.com -d '*.melindaban.com' -d linda-ebert.com -d '*.linda-ebert.com' --server letsencrypt --dns dns_cf --force
docker exec "$ACMESH_CONTAINER" --issue -d ebertek.com -d '*.ebertek.com' --server letsencrypt --dns dns_cf --force
docker exec "$ACMESH_CONTAINER" --issue -d ld25.se -d '*.ld25.se' -d lindi-david.se -d '*.lindi-david.se' --server letsencrypt --dns dns_cf --force
docker exec "$ACMESH_CONTAINER" --toPkcs -d ebi.nu --password "$PASSWORD"
docker exec "$ACMESH_CONTAINER" --toPkcs -d tnt.photo --password "$PASSWORD"
