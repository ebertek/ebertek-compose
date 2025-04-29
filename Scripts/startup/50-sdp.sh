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
done < "$ENV_FILE"

curl -s -k "https://www.smartdnsproxy.com/api/IP/update/$API_KEY"
