#!/bin/sh
set -e
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

docker exec acmesh --issue -d tnt.photo -d '*.tnt.photo' -d '*.int.tnt.photo' -d '*.ext.tnt.photo' --challenge-alias 'tnt.photo' --server letsencrypt --dns dns_cf --force
docker exec acmesh --issue -d melindaban.com -d '*.melindaban.com' --server letsencrypt --dns dns_cf --force
docker exec acmesh --issue -d ebertek.com -d '*.ebertek.com' --server letsencrypt --dns dns_cf --force
docker exec acmesh --issue -d ld25.se -d '*.ld25.se' -d lindi-david.se -d '*.lindi-david.se' --server letsencrypt --dns dns_cf --force
docker exec acmesh --toPkcs -d tnt.photo --password "$PASSWORD"
