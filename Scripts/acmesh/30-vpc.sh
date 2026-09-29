#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_DIR}/${SCRIPT_NAME%.sh}.txt"

SSH_KEY="/home/docker/.ssh/id_rsa"
ACMESH_SOURCE="/volume2/docker/acmesh"

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

for var in HOST PORT USER; do
	eval "value=\${$var:-}"

	if [ -z "$value" ]; then
		error "$var not set in $ENV_FILE"
		exit 1
	fi
done

if [ ! -f "$SSH_KEY" ]; then
	error "SSH key not found: $SSH_KEY"
	exit 1
fi

if [ ! -d "$ACMESH_SOURCE" ]; then
	error "acmesh source directory not found: $ACMESH_SOURCE"
	exit 1
fi

log "Copying acmesh certificate data to $HOST"

scp \
	-r \
	-P "$PORT" \
	-i "$SSH_KEY" \
	"$ACMESH_SOURCE" \
	"$USER@$HOST:~/"

log "Updating certificate files on $HOST"

ssh \
	-i "$SSH_KEY" \
	-l "$USER" \
	-p "$PORT" \
	"$HOST" <<'EOF'
set -eu

ARCHIVE_DIR="/mnt/data/tntphoto_certbot_config/_data/archive"
ACMESH_DIR="/root/acmesh"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

log "Replacing certificate archive contents"

sudo rm -rf "${ARCHIVE_DIR:?}/"*
sudo cp -R "$ACMESH_DIR/"* "$ARCHIVE_DIR/"
sudo rm -rf "$ACMESH_DIR"

log "Renaming certificate directories"

sudo mv "$ARCHIVE_DIR/ebertek.com_ecc" "$ARCHIVE_DIR/ebertek.com"
sudo mv "$ARCHIVE_DIR/linda-ebert.com_ecc" "$ARCHIVE_DIR/linda-ebert.com"
sudo mv "$ARCHIVE_DIR/tnt.photo_ecc" "$ARCHIVE_DIR/tnt.photo"
sudo mv "$ARCHIVE_DIR/ld25.se_ecc" "$ARCHIVE_DIR/ld25.se"

log "Updating certificate permissions"

sudo chmod 0644 "$ARCHIVE_DIR/ebertek.com/"*
sudo chmod 0644 "$ARCHIVE_DIR/linda-ebert.com/"*
sudo chmod 0644 "$ARCHIVE_DIR/tnt.photo/"*
sudo chmod 0644 "$ARCHIVE_DIR/ld25.se/"*

sudo chmod 0600 "$ARCHIVE_DIR/ebertek.com/ebertek.com.key"
sudo chmod 0600 "$ARCHIVE_DIR/linda-ebert.com/linda-ebert.com.key"
sudo chmod 0600 "$ARCHIVE_DIR/tnt.photo/tnt.photo.key"
sudo chmod 0600 "$ARCHIVE_DIR/ld25.se/ld25.se.key"

sudo chown -R 101:101 "$ARCHIVE_DIR"

NGINX_CONTAINER=$(
	docker ps \
		--filter "label=com.docker.compose.service=nginx" \
		--format '{{.ID}}' |
		head -n1
)

if [ -z "$NGINX_CONTAINER" ]; then
	error "No running container found for service nginx"
	exit 1
fi

log "Reloading nginx"

sudo docker exec "$NGINX_CONTAINER" \
	sh -c "/usr/sbin/nginx -s reload"

log "Remote certificate update completed successfully"
EOF

log "VPC certificate deployment completed successfully"
