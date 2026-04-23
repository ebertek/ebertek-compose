#!/bin/bash
set -euo pipefail

IFACE="macvlan1"
PARENT="ovs_bond0"

HOST_ADDR4="10.4.21.1/32"
SUBNET4="10.4.20.0/23"

HOST_ADDR6="2001:9b1:25fc:6900:421::1/128"
SUBNET6="2001:9b1:25fc:6900:421::/80"

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

# Ensure the IP addresses are present
ip link set "$IFACE" up

ip -4 addr flush dev "$IFACE"
ip -4 addr add "$HOST_ADDR4" dev "$IFACE"
ip -4 route replace "$SUBNET4" dev "$IFACE"

ip -6 addr flush dev "$IFACE" scope local
ip -6 addr add "$HOST_ADDR6" dev "$IFACE"
ip -6 route replace "$SUBNET6" dev "$IFACE"
