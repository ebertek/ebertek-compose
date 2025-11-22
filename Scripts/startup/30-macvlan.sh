#!/bin/bash
set -euo pipefail

IFACE="macvlan1"
PARENT="ovs_bond0"
ADDR4="10.4.21.1/24"

# Wait for parent interface to exist and be up (timeout: 30s)
for _ in {1..30}; do
	if ip link show "$PARENT" &>/dev/null; then
		state=$(ip -o link show "$PARENT" | awk '{print $9}')
		if [[ "$state" == "UP" || "$state" == "LOWER_UP" ]]; then
			break
		fi
	fi
	sleep 1
done

# Create macvlan only if it doesn't exist yet
if ! ip link show "$IFACE" &>/dev/null; then
	ip link add "$IFACE" link "$PARENT" type macvlan mode bridge
fi

# Ensure the IPv4 address is present
ip -4 addr flush dev "$IFACE"
ip addr add "$ADDR4" dev "$IFACE"

ip link set "$IFACE" up
