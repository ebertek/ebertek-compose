#!/usr/bin/env bash
set -euo pipefail

response=$(mktemp)
trap 'rm -f "$response"' EXIT
fetch=(curl --silent --show-error --proto '=https' --max-time 8
	--retry 2 --retry-delay 2 --retry-max-time 25 --output "$response")

failed=0
if ! status=$("${fetch[@]}" --write-out '%{http_code}' https://hass.ebi.nu/api/) ||
	[[ "$status" != 401 || $(<"$response") != '401: Unauthorized' ]]; then
	echo 'Home Assistant API did not return the expected authentication response' >&2
	failed=1
fi

issuer=https://keycloak.ebi.nu/realms/ygg
if ! "${fetch[@]}" --fail "$issuer/.well-known/openid-configuration" ||
	! jq -e --arg issuer "$issuer" '.issuer == $issuer' "$response" >/dev/null 2>&1; then
	echo 'Keycloak discovery did not return the expected issuer' >&2
	failed=1
fi

if ((failed)); then
	exit 1
fi

if [[ "${1:-}" == --probe-only ]]; then
	echo 'Home Assistant API and Keycloak discovery responded as expected'
	exit 0
fi

if (($#)); then
	echo 'Unexpected argument' >&2
	exit 2
fi

url=''
read -r url <"${CREDENTIALS_DIRECTORY:?}/heartbeat-url" || [[ -n "$url" ]]
if [[ ! "$url" =~ ^http://127\.0\.0\.1:18000/ping/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
	echo 'Invalid local Healthchecks destination' >&2
	exit 2
fi

if ! printf 'url = "%s"\n' "$url" |
	curl --config - --silent --fail --proto '=http' --noproxy '*' --max-time 5 \
		--request POST --output /dev/null; then
	echo 'Local Healthchecks did not accept the ingress heartbeat' >&2
	exit 1
fi
