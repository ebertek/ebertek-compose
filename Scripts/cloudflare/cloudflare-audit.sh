#!/usr/bin/env bash
# Cloudflare audit; optionally performs guarded writes for Pleiades/Komodo.
set -Eeuo pipefail

root="/home/docker/ygg-compose"
python="/home/docker/cloudflare/.venv/bin/python"
# Credentials are supplied only by the private GitOps source repository.
# The merged checkout is read-only; never generate credentials here.
credentials="${root}/Scripts/cloudflare/cloudflare.env"

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

# Map the existing CF_* credential names to the controller's expected names.
# The token is also accepted as CF_API_TOKEN for compatibility.
export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"
export CLOUDFLARE_ACCOUNT_ID="${CF_ACCOUNT_ID:-${CLOUDFLARE_ACCOUNT_ID:-}}"
export CLOUDFLARE_TUNNEL_ID="${CF_TUNNEL_ID:-${CLOUDFLARE_TUNNEL_ID:-}}"
export CLOUDFLARE_EBI_ZONE_ID="${CF_ZONE_EBI_NU:-${CLOUDFLARE_EBI_ZONE_ID:-}}"
export CLOUDFLARE_YGG_ZONE_ID="${CF_ZONE_YGG_NU:-${CLOUDFLARE_YGG_ZONE_ID:-}}"

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
