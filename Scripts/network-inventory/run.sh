#!/usr/bin/env bash
# Read-only scanner; observations are intentionally outside GitOps.
set -Eeuo pipefail

root="/home/docker/ygg-compose"
state="/home/docker/cloudflare/network-inventory"
private_env="${root}/Scripts/network-inventory/network-inventory.env"

for executable in nmap avahi-browse python3 flock; do
  if ! command -v "${executable}" >/dev/null 2>&1; then
    echo "ERROR: Required executable missing: ${executable}" >&2
    exit 2
  fi
done

# Only private GitOps configuration can opt in to Discord delivery.
unset YGG_NETWORK_DISCORD_WEBHOOK_URL
if [[ -f "${private_env}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${private_env}"
  set +a
fi

if [[ ! -f "${root}/Scripts/cloudflare/static-hosts.json" ]]; then
  echo "ERROR: Missing active static-hosts.json inventory" >&2
  exit 2
fi

install -d -m 0700 "${state}"
exec 9>"${state}/.audit.lock"
if ! flock -n 9; then
  echo "Network audit already running; skipping duplicate execution."
  exit 0
fi

exec python3 "${root}/Scripts/network-inventory/audit.py" \
  --inventory "${root}/Scripts/cloudflare/static-hosts.json" \
  --state-dir "${state}" "$@"
