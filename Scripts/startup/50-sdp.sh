#!/bin/sh
set -e
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_NAME%.sh}.txt"
[ -f "$ENV_FILE" ] || { echo "Error: $ENV_FILE file not found!"; exit 1; }
export "$(grep -v '^#' "$ENV_FILE" | xargs)"

curl -s -k "https://www.smartdnsproxy.com/api/IP/update/$API_KEY"
