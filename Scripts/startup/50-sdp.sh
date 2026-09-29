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

if [ -z "${API_KEY:-}" ]; then
	error "API_KEY not set in $ENV_FILE"
	exit 1
fi

log "Updating Smart DNS Proxy IP"

curl \
	--fail-with-body \
	--silent \
	--show-error \
	--insecure \
	"https://www.smartdnsproxy.com/api/IP/update/$API_KEY"

printf '\n'

log "Smart DNS Proxy IP update completed successfully"
