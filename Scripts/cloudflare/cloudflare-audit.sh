#!/usr/bin/env bash
# Cloudflare audit; optionally performs guarded writes for Pleiades/Komodo.
set -Eeuo pipefail

root="/home/docker/ygg-compose"
python="/home/docker/cloudflare/.venv/bin/python"
credentials="${root}/terraform/cloudflare/cloudflare.env"

if [[ ! -x "${python}" || ! -r "${credentials}" ]]; then
	echo "ERROR: Missing Cloudflare Python environment or credentials" >&2
	exit 1
fi

# Keep the existing GitOps checkout read-only.
cd "${root}"
set -a
# shellcheck disable=SC1090
source "${credentials}"
set +a

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
	echo "ERROR: CLOUDFLARE_API_TOKEN is not configured" >&2
	exit 1
fi

# Unattended writes require a separate, owner-only opt-in outside GitOps.
# Existing policy updates are allowed only after unattended safety checks.
if [[ -f "/home/docker/cloudflare/enable-auto" ]]; then
	exec "${python}" Scripts/cloudflare/cloudflare-manage.py --auto
fi

exec "${python}" Scripts/cloudflare/cloudflare-live.py
