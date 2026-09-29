#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_DIR}/${SCRIPT_NAME%.sh}.txt"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

if [ ! -f "$ENV_FILE" ]; then
	error "$ENV_FILE file not found"
	exit 1
fi

while IFS='=' read -r key value; do
	[ -z "$key" ] && continue

	case "$key" in
	\#*) continue ;;
	esac

	export "$key=$value"
done <"$ENV_FILE"

if [ -z "${PASSWORD:-}" ]; then
	error "PASSWORD not set in $ENV_FILE"
	exit 1
fi

ACMESH_CONTAINER=$(
	docker ps \
		--filter "label=com.docker.compose.service=acmesh" \
		--format '{{.ID}}' |
		head -n1
)

if [ -z "$ACMESH_CONTAINER" ]; then
	error "No running acmesh container found"
	exit 1
fi

log "Using acmesh container $ACMESH_CONTAINER"

log "Issuing certificate for ebi.nu and ygg.nu"
docker exec "$ACMESH_CONTAINER" \
	--issue \
	-d ebi.nu \
	-d '*.ebi.nu' \
	-d ygg.nu \
	-d '*.ygg.nu' \
	--server letsencrypt \
	--dns dns_cf \
	--force

log "Issuing certificate for tnt.photo"
docker exec "$ACMESH_CONTAINER" \
	--issue \
	-d tnt.photo \
	-d '*.tnt.photo' \
	--server letsencrypt \
	--dns dns_cf \
	--force

log "Issuing certificate for linda-ebert.com"
docker exec "$ACMESH_CONTAINER" \
	--issue \
	-d linda-ebert.com \
	-d '*.linda-ebert.com' \
	--server letsencrypt \
	--dns dns_cf \
	--force

log "Issuing certificate for ebertek.com"
docker exec "$ACMESH_CONTAINER" \
	--issue \
	-d ebertek.com \
	-d '*.ebertek.com' \
	--server letsencrypt \
	--dns dns_cf \
	--force

log "Issuing certificates for ld25.se and lindi-david.se"
docker exec "$ACMESH_CONTAINER" \
	--issue \
	-d ld25.se \
	-d '*.ld25.se' \
	-d lindi-david.se \
	-d '*.lindi-david.se' \
	--server letsencrypt \
	--dns dns_cf \
	--force

log "Exporting ebi.nu certificate to PKCS"
docker exec "$ACMESH_CONTAINER" \
	--toPkcs \
	-d ebi.nu \
	--password "$PASSWORD"

log "Exporting tnt.photo certificate to PKCS"
docker exec "$ACMESH_CONTAINER" \
	--toPkcs \
	-d tnt.photo \
	--password "$PASSWORD"

log "acme.sh certificate update completed successfully"
