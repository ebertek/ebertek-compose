#!/bin/sh
set -e
SCRIPT_NAME=$(basename "$0")
ENV_FILE="${SCRIPT_NAME%.sh}.txt"
[ -f "$ENV_FILE" ] || {
	echo "Error: $ENV_FILE file not found!"
	exit 1
}
export "$(grep -v '^#' "$ENV_FILE" | xargs)"

echo "Preparing all variables:"

# Define the Unique Local Address (ULA) prefix
PREFIX_PART="${ULA_PREFIX%%::*}:"

# Fetch the Matter devices' IPv6 addresses
echo "Fetching the Matter devices' IPv6 addresses..."
ULA_ADDRESSES=$(avahi-browse -rpt _matter._tcp | grep -E "=;.*${PREFIX_PART}" | awk -F ";" '{print $8}' | sort -u)

# Fetch the Thread Border Router's link-local address
echo "Fetching the Thread Border Router's link-local address..."
THREAD_BR=$(rdisc6 ovs_bond0 | grep -A4 "$ULA_PREFIX" | grep "from" | head -1 | awk '{print $2}')

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
echo "Getting the dynamic IPv6 address of eth0 inside the Docker container..."
DYNAMIC_IPV6=$(docker exec matter-server ip -6 addr show eth0 | awk '/scope global dynamic/{print $2}' | cut -d/ -f1)

# Ensure DYNAMIC_IPV6 is not empty
if [ -z "$DYNAMIC_IPV6" ]; then
	echo "Error: Unable to fetch dynamic IPv6 address from container."
	exit 1
fi

echo ""
echo "============== IPv6 Route Setup Summary =============="
echo "ULA Prefix:          ${ULA_PREFIX}"
echo "Thread BR Address:   ${THREAD_BR}"
echo "Dynamic IPv6 (eth0): ${DYNAMIC_IPV6}"
echo "Matter Devices:"
echo "${ULA_ADDRESSES}" | sed 's/^/  - /'
echo "======================================================"
echo ""

# Run the route management commands inside the Docker container
echo "Running the route management commands inside the Docker container:"
docker exec "$MATTER_SERVER_CONTAINER" sh -c "
	ULA_PREFIX=\"$ULA_PREFIX\"
	THREAD_BR=\"$THREAD_BR\"
	DYNAMIC_IPV6=\"$DYNAMIC_IPV6\"
	ULA_ADDRESSES=\"$ULA_ADDRESSES\"

	echo \"Checking if a route to \${ULA_PREFIX} already exists...\"
	if ip -6 route show | grep -q \"\$ULA_PREFIX\"; then
		echo \"Removing old route...\"
		ip -6 route del \"\$ULA_PREFIX\"
	fi

	echo \"Adding the new route via \${THREAD_BR} with source address \${DYNAMIC_IPV6}...\"
	if [ -n \"\$DYNAMIC_IPV6\" ]; then
		ip -6 route add \"\$ULA_PREFIX\" via \"\$THREAD_BR\" dev eth0 src \"\$DYNAMIC_IPV6\"
	fi

	echo \"Checking connectivity...\"
	for ip in \${ULA_ADDRESSES}; do
		if ping6 -q -c 1 \$ip >/dev/null 2>&1; then
			echo \"\$ip is reachable.\"
		else
			echo \"\$ip is not reachable.\"
		fi
	done
"
