#!/bin/bash
set -e
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_NAME%.sh}.txt"
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "Error: $ENV_FILE file not found!"
  exit 1
fi

curl -s -k "https://www.smartdnsproxy.com/api/IP/update/$API_KEY"
