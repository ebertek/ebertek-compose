#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_DIR}/${SCRIPT_NAME%.sh}.txt"

ACME_HOME="/volume2/docker/acmesh"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

certificate_state() {
	for file in \
		"$ACME_HOME/ebertek.com_ecc/fullchain.cer" \
		"$ACME_HOME/ebi.nu_ecc/fullchain.cer" \
		"$ACME_HOME/linda-ebert.com_ecc/fullchain.cer" \
		"$ACME_HOME/tnt.photo_ecc/fullchain.cer"; do

		if [ -f "$file" ]; then
			sha256sum "$file"
		else
			printf 'MISSING %s\n' "$file"
		fi
	done
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

before=$(certificate_state)

log "Checking certificates for renewal"

docker exec "$ACMESH_CONTAINER" \
	--renew-all \
	--treat-skip-as-success

after=$(certificate_state)

if [ "$before" = "$after" ]; then
	log "No certificates were renewed"
	exit 10
fi

log "One or more certificates were renewed"

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

log "acme.sh certificate renewal completed successfully"
