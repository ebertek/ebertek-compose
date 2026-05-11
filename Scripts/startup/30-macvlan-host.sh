#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Host-side macvlan interface name
# Used so the host can communicate with macvlan containers
# ---------------------------------------------------------------------------
HOST_IFACE="macvlan1-host"

# ---------------------------------------------------------------------------
# Physical/Open vSwitch parent interface
# ---------------------------------------------------------------------------
PARENT="enp86s0"

# ---------------------------------------------------------------------------
# Docker IPv4 configuration
# ---------------------------------------------------------------------------

# Range reserved for Docker macvlan containers
DOCKER_RANGE4="10.4.21.0/25"

# Host-side macvlan IPv4 address
HOST_ADDR4="10.4.21.1/32"

# DNS server (if assigned by DHCP but running on macvlan)
DNS_ADDR4="10.4.21.34"

# ---------------------------------------------------------------------------
# Docker IPv6 configuration
# ---------------------------------------------------------------------------

# IPv6 range reserved for Docker macvlan containers
DOCKER_RANGE6="2001:9b1:25fc:6900:421::/80"

# Host-side macvlan IPv6 address
HOST_ADDR6="2001:9b1:25fc:6900:421::1/128"

# ---------------------------------------------------------------------------
# Wait for parent interface to exist and become operational
# Prevents boot race conditions
# ---------------------------------------------------------------------------
for _ in {1..30}; do
	if ip link show "${PARENT}" >/dev/null 2>&1; then
		state="$(ip -o link show "${PARENT}" | awk '{print $9}')"

		if [[ "${state}" == "UP" || "${state}" == "LOWER_UP" ]]; then
			break
		fi
	fi

	sleep 1
done

# Abort if parent interface still does not exist
if ! ip link show "${PARENT}" >/dev/null 2>&1; then
	echo "ERROR: Parent interface ${PARENT} does not exist" >&2
	exit 1
fi

# ---------------------------------------------------------------------------
# Create host-side macvlan interface if missing
#
# This is required because:
# - macvlan containers normally cannot talk to the host
# - the host normally cannot talk to macvlan containers
#
# Adding a separate macvlan interface on the host solves this.
# ---------------------------------------------------------------------------
if ! ip link show "${HOST_IFACE}" >/dev/null 2>&1; then
	ip link add \
		"${HOST_IFACE}" \
		link "${PARENT}" \
		type macvlan \
		mode bridge
fi

# Bring host-side macvlan interface up
ip link set "${HOST_IFACE}" up

# ---------------------------------------------------------------------------
# Configure IPv4 on host-side macvlan interface
# ---------------------------------------------------------------------------

# Remove old IPv4 addresses to avoid duplicates
ip -4 addr flush dev "${HOST_IFACE}"

# Assign host IPv4 address
ip -4 addr add "${HOST_ADDR4}" dev "${HOST_IFACE}"

# Remove bogus DHCP-provided host route for macvlan DNS container, if present.
# It must not go via the physical parent interface.
ip -4 route del "${DNS_ADDR4}/32" dev "${PARENT}" 2>/dev/null || true

# Route only the Docker macvlan allocation range through the host macvlan interface.
ip -4 route replace "${DOCKER_RANGE4}" dev "${HOST_IFACE}" src "${HOST_ADDR4%/*}"

# ---------------------------------------------------------------------------
# Disable IPv6 SLAAC / Router Advertisement auto-configuration
#
# Prevents Linux from assigning unexpected global IPv6 addresses
# to the host-side macvlan interface.
# ---------------------------------------------------------------------------
sysctl -w "net.ipv6.conf.${HOST_IFACE}.autoconf=0" >/dev/null || true
sysctl -w "net.ipv6.conf.${HOST_IFACE}.accept_ra=0" >/dev/null || true

# ---------------------------------------------------------------------------
# Configure IPv6 on host-side macvlan interface
# ---------------------------------------------------------------------------

# Remove old global IPv6 addresses
ip -6 addr flush dev "${HOST_IFACE}" scope global

# Assign host IPv6 address
ip -6 addr add "${HOST_ADDR6}" dev "${HOST_IFACE}"

# Route only the Docker IPv6 allocation range through this interface
ip -6 route replace "${DOCKER_RANGE6}" dev "${HOST_IFACE}"

# ---------------------------------------------------------------------------
# Finished
# ---------------------------------------------------------------------------
echo "Host macvlan interface '${HOST_IFACE}' is configured"
