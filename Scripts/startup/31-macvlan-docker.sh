#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Docker macvlan network name
# ---------------------------------------------------------------------------
DOCKER_NET="macvlan1"

# ---------------------------------------------------------------------------
# Physical/Open vSwitch parent interface
# ---------------------------------------------------------------------------
PARENT="enp86s0"

# ---------------------------------------------------------------------------
# Docker IPv4 configuration
# ---------------------------------------------------------------------------

# Main LAN subnet
DOCKER_SUBNET4="10.4.20.0/23"

# LAN gateway
DOCKER_GATEWAY4="10.4.20.1"

# Range reserved for Docker macvlan containers
DOCKER_RANGE4="10.4.21.0/25"

# Host-side macvlan IPv4 address
HOST_ADDR4="10.4.21.1/32"

# ---------------------------------------------------------------------------
# Docker IPv6 configuration
# ---------------------------------------------------------------------------

# Main IPv6 LAN prefix
DOCKER_SUBNET6="2001:9b1:25fc:6900::/64"

# IPv6 gateway
DOCKER_GATEWAY6="2001:9b1:25fc:6900::1"

# IPv6 range reserved for Docker macvlan containers
DOCKER_RANGE6="2001:9b1:25fc:6900:421::/80"

# Host-side macvlan IPv6 address
HOST_ADDR6="2001:9b1:25fc:6900:421::1/128"

# ---------------------------------------------------------------------------
# Wait for Docker to be available
# ---------------------------------------------------------------------------
for _ in {1..30}; do
	if docker info >/dev/null 2>&1; then
		break
	fi

	sleep 1
done

if ! docker info >/dev/null 2>&1; then
	echo "ERROR: Docker daemon is not available" >&2
	exit 1
fi

# ---------------------------------------------------------------------------
# Create Docker macvlan network if it does not already exist
# ---------------------------------------------------------------------------
if ! docker network inspect "${DOCKER_NET}" >/dev/null 2>&1; then
	docker network create \
		--driver macvlan \
		--subnet="${DOCKER_SUBNET4}" \
		--gateway="${DOCKER_GATEWAY4}" \
		--ip-range="${DOCKER_RANGE4}" \
		--aux-address="host=${HOST_ADDR4%/*}" \
		--ipv6 \
		--subnet="${DOCKER_SUBNET6}" \
		--gateway="${DOCKER_GATEWAY6}" \
		--ip-range="${DOCKER_RANGE6}" \
		--aux-address="host=${HOST_ADDR6%/*}" \
		--opt parent="${PARENT}" \
		"${DOCKER_NET}"
fi

# ---------------------------------------------------------------------------
# Finished
# ---------------------------------------------------------------------------
echo "Docker macvlan network '${DOCKER_NET}' is ready"
