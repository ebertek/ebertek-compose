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

if [ -z "$HOST_IFACE" ]; then
	echo "Error: HOST_IFACE not set in $ENV_FILE"
	exit 1
fi

echo "Preparing all variables:"

# Fetch Matter Server container ID based on service name
MATTER_SERVER_CONTAINER=$(docker ps --filter "label=com.docker.compose.service=${MATTER_SERVER_SERVICE}" --format '{{.ID}}' | head -n1)
if [ -z "$MATTER_SERVER_CONTAINER" ]; then
	echo "Error: No running container found for service '$MATTER_SERVER_SERVICE'"
	exit 1
fi

# Define the Unique Local Address (ULA) prefix
PREFIX_PART="${ULA_PREFIX%%::*}:"

# Fetch the Matter devices' hostnames and IPv6 ULA addresses
echo "Fetching the IPv6 addresses of all Matter devices..."
ULA_DEVICES=$(
	avahi-browse -rpt _matter._tcp |
		awk -F ";" -v prefix="$PREFIX_PART" '$8 ~ "^" prefix { print $7 ";" $8 }' |
		sort -u
)

if [ -z "$ULA_DEVICES" ]; then
	echo "Error: No Matter devices found with prefix '$PREFIX_PART'"
	exit 1
fi

# Fetch the Thread Border Router's link-local address
echo "Fetching the link-local address of the Thread Border Router..."
THREAD_BR=$(
	rdisc6 "$OVS_IFACE" |
		awk -v prefix="$ULA_PREFIX" '
			index($0, prefix) { want_from = 1; next }
			want_from && $1 == "from" { print $2; exit }
		'
)

# Check if rdisc6 failed to fetch the address
if [ -z "$THREAD_BR" ]; then
	# Fallback to using curl to fetch the Thread Border Router's IPv6 address
	echo "rdisc6 failed to fetch Thread Border Router's IPv6 address, attempting fallback with curl..."
	THREAD_BR=$(curl -k -X GET "https://$UNIFI_HOST/proxy/network/api/s/default/stat/sta" -H "X-API-KEY: $UNIFI_KEY" -H "Accept: application/json" | jq -r --arg MAC "$THREAD_BR_MAC" '.data[] | select(.mac == $MAC) | .ipv6_addresses | if type == "array" then . | map(select(startswith("fe80::"))) | .[0] else select(startswith("fe80::")) end')

	# Ensure THREAD_BR is not empty after fallback
	if [ -z "$THREAD_BR" ]; then
		echo "Error: Unable to fetch Thread Border Router's IPv6 address."
		exit 1
	fi
fi

# Get the dynamic IPv6 address of eth0 inside the Docker container
echo "Fetching the dynamic IPv6 address of eth0 of Matter Server..."
DYNAMIC_IPV6=$(docker exec "$MATTER_SERVER_CONTAINER" sh -lc \
	"hostname -I | tr ' ' '\n' | grep -E '^[0-9a-fA-F]*:.*' | grep -vE '^(fe80:|fd|fc)' | head -n1")

# Ensure DYNAMIC_IPV6 is not empty
if [ -z "$DYNAMIC_IPV6" ]; then
	echo "Error: Unable to fetch dynamic IPv6 address from container."
	exit 1
fi

# Pick a helper image that has iproute2
HELPER_IMAGE=${HELPER_IMAGE:-nicolaka/netshoot}

echo ""
echo "============== IPv6 Route Setup Summary =============="
echo "Matter Server Container: ${MATTER_SERVER_CONTAINER}"
echo "Helper Image:            ${HELPER_IMAGE}"
echo "Host Interface:          ${HOST_IFACE}"
echo "ULA Prefix:              ${ULA_PREFIX}"
echo "Thread BR Address:       ${THREAD_BR}"
echo "Dynamic IPv6 (eth0):     ${DYNAMIC_IPV6}"
echo "Matter Devices:"
echo "$ULA_DEVICES" | awk -F ';' '{printf "  - %-24s %s\n", $1, $2}'
echo "======================================================"
echo ""

# Run the route management commands using a helper container in the same network namespace
echo "Running the route management commands inside the Docker container:"

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

		echo \"Checking if a route to \${ULA_PREFIX} already exists...\"
		if ip -6 route show | grep -q \"^\${ULA_PREFIX}\"; then
			echo \"Removing old route...\"
			ip -6 route del \"\${ULA_PREFIX}\"
		fi

		echo \"Adding the new route via \${THREAD_BR} with source address \${DYNAMIC_IPV6}...\"
		ip -6 route add \"\${ULA_PREFIX}\" via \"\${THREAD_BR}\" dev eth0 src \"\${DYNAMIC_IPV6}\"

		echo \"Checking connectivity...\"
		echo \"\${ULA_DEVICES}\" | while IFS=';' read -r host ipaddr; do
			[ -n \"\$host\" ] || continue

			if ping6 -q -c 1 \"\$ipaddr\" >/dev/null 2>&1; then
				printf '[ OK ] %-24s %s\n' \"\$host\" \"\$ipaddr\"
			else
				printf '[FAIL] %-24s %s\n' \"\$host\" \"\$ipaddr\"
			fi
		done
	"

echo "Done."
