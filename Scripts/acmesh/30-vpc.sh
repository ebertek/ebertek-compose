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

scp -r -P "$PORT" -i /var/services/homes/Hannibal/.ssh/id_rsa /volume2/docker/acmesh "$USER"@"$HOST":~/
ssh "$HOST" -i /var/services/homes/Hannibal/.ssh/id_rsa -l "$USER" -p "$PORT" <<'EOF'
	sudo rm -r /mnt/data/tntphoto_certbot_config/_data/archive/*
	sudo cp -R /root/acmesh/* /mnt/data/tntphoto_certbot_config/_data/archive/
	sudo rm -r /root/acmesh
	sudo mv /mnt/data/tntphoto_certbot_config/_data/archive/ebertek.com_ecc /mnt/data/tntphoto_certbot_config/_data/archive/ebertek.com
	sudo mv /mnt/data/tntphoto_certbot_config/_data/archive/linda-ebert.com_ecc /mnt/data/tntphoto_certbot_config/_data/archive/linda-ebert.com
	sudo mv /mnt/data/tntphoto_certbot_config/_data/archive/tnt.photo_ecc /mnt/data/tntphoto_certbot_config/_data/archive/tnt.photo
	sudo mv /mnt/data/tntphoto_certbot_config/_data/archive/ld25.se_ecc /mnt/data/tntphoto_certbot_config/_data/archive/ld25.se
	sudo chmod 644 /mnt/data/tntphoto_certbot_config/_data/archive/ebertek.com/*
	sudo chmod 644 /mnt/data/tntphoto_certbot_config/_data/archive/linda-ebert.com/*
	sudo chmod 644 /mnt/data/tntphoto_certbot_config/_data/archive/tnt.photo/*
	sudo chmod 644 /mnt/data/tntphoto_certbot_config/_data/archive/ld25.se/*
	sudo chmod 600 /mnt/data/tntphoto_certbot_config/_data/archive/ebertek.com/ebertek.com.key
	sudo chmod 600 /mnt/data/tntphoto_certbot_config/_data/archive/linda-ebert.com/linda-ebert.com.key
	sudo chmod 600 /mnt/data/tntphoto_certbot_config/_data/archive/tnt.photo/tnt.photo.key
	sudo chmod 600 /mnt/data/tntphoto_certbot_config/_data/archive/ld25.se/ld25.se.key
	sudo chown -R 101:101 /mnt/data/tntphoto_certbot_config/_data/archive
	NGINX_CONTAINER=$(docker ps --filter "label=com.docker.compose.service=nginx" --format '{{.ID}}' | head -n1)
	if [ -z "$NGINX_CONTAINER" ]; then
		echo "Error: No running container found for service nginx" >&2
		exit 1
	fi
	sudo docker exec "$NGINX_CONTAINER" sh -c "/usr/sbin/nginx -s reload"
EOF
