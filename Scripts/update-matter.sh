#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_DIR}/${SCRIPT_NAME%.sh}.txt"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

warn() {
	printf '[%s] WARNING: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
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

for var in MATTER_SERVER_SERVICE ULA_PREFIX HOST_IFACE THREAD_BR_MAC; do
	eval "value=\${$var:-}"

	if [ -z "$value" ]; then
		error "$var not set in $ENV_FILE"
		exit 1
	fi
done

log "Preparing Matter route update"

MATTER_SERVER_CONTAINER=$(
	docker ps \
		--filter "label=com.docker.compose.service=${MATTER_SERVER_SERVICE}" \
		--format '{{.ID}}' |
		head -n1
)

if [ -z "$MATTER_SERVER_CONTAINER" ]; then
	error "No running container found for service '$MATTER_SERVER_SERVICE'"
	exit 1
fi

PREFIX_PART="${ULA_PREFIX%%::*}:"

log "Fetching IPv6 addresses of Matter devices"

ULA_DEVICES=$(
	avahi-browse -rpt _matter._tcp |
		awk -F ';' -v prefix="$PREFIX_PART" '$8 ~ "^" prefix { print $7 ";" $8 }' |
		sort -u
)

if [ -z "$ULA_DEVICES" ]; then
	error "No Matter devices found with prefix '$PREFIX_PART'"
	exit 1
fi

log "Fetching Thread Border Router link-local address"

THREAD_BR=$(
	rdisc6 "$HOST_IFACE" |
		awk -v prefix="$ULA_PREFIX" '
			index($0, prefix) { want_from = 1; next }
			want_from && $1 == "from" { print $2; exit }
		'
)

if [ -z "$THREAD_BR" ]; then
	if [ -n "${UNIFI_HOST:-}" ] && [ -n "${UNIFI_KEY:-}" ]; then
		warn "rdisc6 failed; attempting UniFi fallback"

		THREAD_BR=$(
			curl -k -X GET "https://$UNIFI_HOST/proxy/network/api/s/default/stat/sta" \
				-H "X-API-KEY: $UNIFI_KEY" \
				-H "Accept: application/json" |
				jq -r --arg MAC "$THREAD_BR_MAC" '
					.data[]
					| select(.mac == $MAC)
					| .ipv6_addresses
					| if type == "array" then
						map(select(startswith("fe80::"))) | .[0]
					else
						select(startswith("fe80::"))
					end
				'
		)
	else
		warn "rdisc6 failed and UNIFI_HOST / UNIFI_KEY are not set; skipping UniFi fallback"
	fi

	if [ -z "$THREAD_BR" ]; then
		error "Unable to fetch Thread Border Router IPv6 address"
		exit 1
	fi
fi

log "Fetching dynamic IPv6 address of Matter Server"

DYNAMIC_IPV6=$(
	docker exec "$MATTER_SERVER_CONTAINER" sh -lc \
		"hostname -I | tr ' ' '\n' | grep -E '^[0-9a-fA-F]*:.*' | grep -vE '^(fe80:|fd|fc)' | head -n1"
)

if [ -z "$DYNAMIC_IPV6" ]; then
	error "Unable to fetch dynamic IPv6 address from Matter Server container"
	exit 1
fi

HELPER_IMAGE=${HELPER_IMAGE:-nicolaka/netshoot}

printf '\n'
printf '%s\n' "=================== IPv6 Route Setup Summary ==================="
printf 'Matter Server Container: %s\n' "$MATTER_SERVER_CONTAINER"
printf 'Helper Image:            %s\n' "$HELPER_IMAGE"
printf 'Host Interface:          %s\n' "$HOST_IFACE"
printf 'ULA Prefix:              %s\n' "$ULA_PREFIX"
printf 'Thread BR Address:       %s\n' "$THREAD_BR"
printf 'Dynamic IPv6 (eth0):     %s\n' "$DYNAMIC_IPV6"
printf '%s\n' "Matter Devices:"
printf '%s\n' "$ULA_DEVICES" | awk -F ';' '{printf " - %-24s %s\n", $1, $2}'
printf '%s\n' "================================================================"
printf '\n'

log "Running route management commands inside Matter Server network namespace"

docker run --rm \
	--network "container:${MATTER_SERVER_CONTAINER}" \
	--cap-add NET_ADMIN \
	"$HELPER_IMAGE" sh -lc "
		set -e

		ULA_PREFIX=\"$ULA_PREFIX\"
		THREAD_BR=\"$THREAD_BR\"
		DYNAMIC_IPV6=\"$DYNAMIC_IPV6\"
		ULA_DEVICES=\$(
cat <<'EOF'
$ULA_DEVICES
EOF
)

		echo \"Ensuring route exists...\"
		OLD_ROUTE=\$(ip -6 route show \"\${ULA_PREFIX}\" 2>/dev/null | head -n1 || true)

		if [ -n \"\$OLD_ROUTE\" ]; then
			echo \"Existing route: \$OLD_ROUTE\"
		fi

		ip -6 route replace \"\${ULA_PREFIX}\" via \"\${THREAD_BR}\" dev eth0 src \"\${DYNAMIC_IPV6}\"

		NEW_ROUTE=\$(ip -6 route show \"\${ULA_PREFIX}\" 2>/dev/null | head -n1 || true)
		echo \"Effective route: \$NEW_ROUTE\"

		echo \"Checking connectivity...\"
		echo \"\${ULA_DEVICES}\" | while IFS=';' read -r host ipaddr; do
			[ -n \"\$host\" ] || continue

			if ping6 -q -c 1 -W 5 \"\$ipaddr\" >/dev/null 2>&1; then
				printf '[ OK ] %-24s %s\n' \"\$host\" \"\$ipaddr\"
			else
				printf '[FAIL] %-24s %s\n' \"\$host\" \"\$ipaddr\"
			fi
		done
	"

log "Matter route update completed successfully"
